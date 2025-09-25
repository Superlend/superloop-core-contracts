// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {ISuperloop} from "../interfaces/ISuperloop.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {AaveV3ActionModule} from "../modules/aave/AaveV3ActionModule.sol";
import {UniversalDexModule} from "../modules/dex/UniversalDexModule.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ISuperloopLegacy} from "./ISuperloopLegacy.sol";

/**
 * @title MigrationHelper
 * @author Superlend
 * @notice Helper contract for migrating vault positions from old vault to new vault
 * @dev Uses Aave flash loans to atomically migrate user positions while maintaining exchange rates
 *
 * Migration Process:
 * 1. Validates old vault state and user balances
 * 2. Takes flash loan of borrowed asset amount
 * 3. Repays old vault's debt and withdraws collateral
 * 4. Transfers assets to new vault
 * 5. Deposits collateral and borrows debt in new vault
 * 6. Repays flash loan
 * 7. Mints shares to users in new vault
 * 8. Validates exchange rate preservation
 */
contract MigrationHelper is FlashLoanSimpleReceiverBase, Ownable, ReentrancyGuard {
    /**
     * @notice Structure to store vault state data during migration
     * @param totalSupply Total supply of vault shares
     * @param totalAssets Total underlying assets in the vault
     * @param balances Array of user balances in the vault
     * @param borrowBalance Total borrowed amount from Aave
     * @param lendBalance Total lent amount to Aave
     */
    struct VaultStateData {
        uint256 totalSupply;
        uint256 totalAssets;
        uint256[] balances;
        uint256 borrowBalance;
        uint256 lendBalance;
    }

    /// @notice Aave pool data provider for querying user reserve data
    IPoolDataProvider immutable poolDataProvider;
    /// @notice Common decimal factor for exchange rate calculations (10^20)
    uint256 immutable commonDecimalFactor;
    /// @notice Module for repaying Aave positions
    AaveV3ActionModule immutable repayModule;
    /// @notice Module for withdrawing from Aave positions
    AaveV3ActionModule immutable withdrawModule;
    /// @notice Module for depositing to Aave positions
    AaveV3ActionModule immutable depositModule;
    /// @notice Module for borrowing from Aave positions
    AaveV3ActionModule immutable borrowModule;
    /// @notice Universal DEX module for token transfers
    UniversalDexModule immutable dexModule;
    /// @notice Placeholder asset for DEX module operations
    address immutable placeholderAsset;

    /**
     * @notice Emitted when migration is successfully completed
     * @param oldVault Address of the old vault being migrated from
     * @param newVault Address of the new vault being migrated to
     * @param oldExchangeRate Exchange rate of the old vault before migration
     * @param newExchangeRate Exchange rate of the new vault after migration
     */
    event MigrationProcessed(
        address indexed oldVault, address indexed newVault, uint256 oldExchangeRate, uint256 newExchangeRate
    );

    /**
     * @notice Constructor for MigrationHelper contract
     * @param _poolAddressesProvider Aave pool addresses provider contract
     * @param _repayModule Address of the repay module for Aave operations
     * @param _withdrawModule Address of the withdraw module for Aave operations
     * @param _depositModule Address of the deposit module for Aave operations
     * @param _borrowModule Address of the borrow module for Aave operations
     * @param _dexModule Address of the universal DEX module for token transfers
     * @param _placeholderAsset Address of the placeholder asset for DEX operations
     */
    constructor(
        address _poolAddressesProvider,
        address _repayModule,
        address _withdrawModule,
        address _depositModule,
        address _borrowModule,
        address _dexModule,
        address _placeholderAsset
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_poolAddressesProvider)) Ownable(msg.sender) {
        poolDataProvider = IPoolDataProvider(ADDRESSES_PROVIDER.getPoolDataProvider());
        commonDecimalFactor = 10 ** 20;
        repayModule = AaveV3ActionModule(_repayModule);
        withdrawModule = AaveV3ActionModule(_withdrawModule);
        depositModule = AaveV3ActionModule(_depositModule);
        borrowModule = AaveV3ActionModule(_borrowModule);
        dexModule = UniversalDexModule(_dexModule);
        placeholderAsset = _placeholderAsset;
    }

    /**
     * @notice Migrates user positions from old vault to new vault atomically
     * @dev Uses flash loans to ensure atomic migration while preserving exchange rates
     * @param oldVault Address of the vault to migrate from
     * @param newVault Address of the vault to migrate to
     * @param users Array of user addresses to migrate
     * @param lendAsset Address of the asset being lent to Aave
     * @param borrowAsset Address of the asset being borrowed from Aave
     * @param batches Number of batches to perform the migration in
     * @return success True if migration completed successfully
     */
    function migrate(
        address oldVault,
        address newVault,
        address[] calldata users,
        address lendAsset,
        address borrowAsset,
        uint256 batches
    ) external onlyOwner nonReentrant returns (bool) {
        // Ensure withdraw manager has no balance to prevent conflicts
        address blackListedUser = ISuperloopLegacy(oldVault).withdrawManagerModule();
        uint256 blackListedUserBalance = ISuperloop(oldVault).balanceOf(blackListedUser);
        if (blackListedUserBalance > 0) {
            revert("withdraw manager must be empty");
        }

        // Capture old vault state before migration
        VaultStateData memory oldVaultState = _getVaultState(oldVault, users, lendAsset, borrowAsset);
        _validateUserBalancesWithTotalSupply(oldVaultState);

        // Execute the migration using flash loan
        _performMigration(oldVault, lendAsset, borrowAsset, oldVaultState, newVault, batches);

        // Mint shares to users in the new vault
        for (uint256 i = 0; i < users.length; i++) {
            ISuperloop(newVault).mintShares(users[i], oldVaultState.balances[i]);
        }

        // Capture new vault state after migration
        VaultStateData memory newVaultState = _getVaultState(newVault, users, lendAsset, borrowAsset);
        _validateUserBalancesWithTotalSupply(newVaultState);

        // Validate exchange rate preservation (allow 0.05% tolerance)
        uint256 oldExchangeRate = (oldVaultState.totalAssets * commonDecimalFactor) / oldVaultState.totalSupply;
        uint256 newExchangeRate = (newVaultState.totalAssets * commonDecimalFactor) / newVaultState.totalSupply;
        uint256 diff =
            oldExchangeRate > newExchangeRate ? oldExchangeRate - newExchangeRate : newExchangeRate - oldExchangeRate;
        uint256 percentageChangeInExchangeRate = (diff * 10000) / oldExchangeRate;

        require(percentageChangeInExchangeRate <= 5, "Exchange rates do not match"); // 0.05% change in exchange rate is allowed

        emit MigrationProcessed(oldVault, newVault, oldExchangeRate, newExchangeRate);

        return true;
    }

    /**
     * @notice Flash loan callback function called by Aave pool
     * @dev Executes the actual migration logic within the flash loan context
     * @param asset Address of the asset that was flash loaned
     * @param amount Amount of the asset that was flash loaned
     * @param premium Premium fee for the flash loan
     * @param params Encoded parameters containing migration data
     * @return success True if operation completed successfully
     */
    function executeOperation(address asset, uint256 amount, uint256 premium, address, bytes calldata params)
        external
        returns (bool)
    {
        require(msg.sender == address(POOL), "Only pool can call flashloan callback");

        // Decode migration parameters from flash loan callback data
        (
            address oldVault,
            uint256 oldVaultLendBalance,
            uint256 oldVaultBorrowBalance,
            address lendAsset,
            address borrowAsset,
            address newVault
        ) = abi.decode(params, (address, uint256, uint256, address, address, address));

        // Execute the core migration logic
        _executeMigration(
            oldVault, newVault, lendAsset, borrowAsset, oldVaultBorrowBalance, oldVaultLendBalance, premium
        );

        // Approve the pool to pull the flash loan amount plus premium
        SafeERC20.forceApprove(IERC20(asset), address(POOL), amount + premium);
        return true;
    }

    /**
     * @notice Captures the current state of a vault including user balances and Aave positions
     * @param vaultAddress Address of the vault to query
     * @param users Array of user addresses to get balances for
     * @param lendAsset Address of the asset being lent to Aave
     * @param borrowAsset Address of the asset being borrowed from Aave
     * @return vaultState Complete vault state data
     */
    function _getVaultState(address vaultAddress, address[] calldata users, address lendAsset, address borrowAsset)
        internal
        view
        returns (VaultStateData memory)
    {
        ISuperloop vault = ISuperloop(vaultAddress);
        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();
        uint256[] memory balances = new uint256[](users.length);

        // Get individual user balances
        for (uint256 i = 0; i < users.length; i++) {
            balances[i] = vault.balanceOf(users[i]);
        }

        // Get Aave position data for the vault
        (uint256 lendBalance,,,,,,,,) = poolDataProvider.getUserReserveData(lendAsset, vaultAddress);
        (,, uint256 borrowBalance,,,,,,) = poolDataProvider.getUserReserveData(borrowAsset, vaultAddress);

        return VaultStateData({
            totalSupply: totalSupply,
            totalAssets: totalAssets,
            balances: balances,
            lendBalance: lendBalance,
            borrowBalance: borrowBalance
        });
    }

    /**
     * @notice Validates that the sum of individual user balances equals the total supply
     * @dev Ensures data integrity before and after migration
     * @param vaultState Vault state data containing balances and total supply
     */
    function _validateUserBalancesWithTotalSupply(VaultStateData memory vaultState) internal pure {
        uint256 calculatedTotalSupply = 0;
        for (uint256 i = 0; i < vaultState.balances.length; i++) {
            calculatedTotalSupply += vaultState.balances[i];
        }
        require(calculatedTotalSupply == vaultState.totalSupply, "Calculated total supply does not match total supply");
    }

    /**
     * @notice Initiates the migration by taking a flash loan of the borrowed asset
     * @dev The flash loan amount equals the old vault's borrow balance
     * @param oldVault Address of the vault to migrate from
     * @param lendAsset Address of the asset being lent to Aave
     * @param borrowAsset Address of the asset being borrowed from Aave
     * @param oldVaultState Current state of the old vault
     * @param newVault Address of the vault to migrate to
     * @param batches Number of batches to perform the migration in
     */
    function _performMigration(
        address oldVault,
        address lendAsset,
        address borrowAsset,
        VaultStateData memory oldVaultState,
        address newVault,
        uint256 batches // count of batches
    ) internal {
        uint256 borrowBalance = oldVaultState.borrowBalance;
        uint256 lendBalance = oldVaultState.lendBalance;

        uint256 borrowBalanceBatch = borrowBalance / batches;
        uint256 lendBalanceBatch = lendBalance / batches;
        for (uint256 i = 0; i < batches; i++) {
            if (i == batches - 1) {
                (uint256 lendBalanceRemainingActual,,,,,,,,) = poolDataProvider.getUserReserveData(lendAsset, oldVault);
                (,, uint256 borrowBalanceRemainingActual,,,,,,) =
                    poolDataProvider.getUserReserveData(borrowAsset, oldVault);

                borrowBalanceBatch = borrowBalanceRemainingActual;
                lendBalanceBatch = lendBalanceRemainingActual;
            }

            // Encode migration parameters for the flash loan callback
            bytes memory callbackData =
                abi.encode(oldVault, lendBalanceBatch, borrowBalanceBatch, lendAsset, borrowAsset, newVault);

            // Take flash loan of the borrowed asset amount
            POOL.flashLoanSimple(address(this), borrowAsset, borrowBalanceBatch, callbackData, 0);

            borrowBalance = borrowBalance >= borrowBalanceBatch ? borrowBalance - borrowBalanceBatch : 0;
            lendBalance = lendBalance >= lendBalanceBatch ? lendBalance - lendBalanceBatch : 0;
        }
    }

    /**
     * @notice Executes the core migration logic within the flash loan callback
     * @dev Performs the actual asset transfers and position updates
     * @param oldVault Address of the vault to migrate from
     * @param newVault Address of the vault to migrate to
     * @param lendAsset Address of the asset being lent to Aave
     * @param borrowAsset Address of the asset being borrowed from Aave
     * @param borrowBalance Amount of borrowed asset to migrate
     * @param lendBalance Amount of lent asset to migrate
     * @param premium Flash loan premium fee
     */
    function _executeMigration(
        address oldVault,
        address newVault,
        address lendAsset,
        address borrowAsset,
        uint256 borrowBalance,
        uint256 lendBalance,
        uint256 premium
    ) internal {
        // Prepare and execute withdrawal operations on old vault
        DataTypes.ModuleExecutionData[] memory moduleExecutionDataWithdraw =
            _perpareWithdrawCalls(oldVault, newVault, lendAsset, borrowAsset, borrowBalance, lendBalance);

        ISuperloop(oldVault).operate(moduleExecutionDataWithdraw);

        // Prepare and execute deposit operations on new vault
        DataTypes.ModuleExecutionData[] memory moduleExecutionDataDeposit =
            _perpareDepositCalls(lendAsset, borrowAsset, borrowBalance + premium, lendBalance);

        ISuperloop(newVault).operate(moduleExecutionDataDeposit);
    }

    /**
     * @notice Prepares module execution data for withdrawing assets from the old vault
     * @dev Creates operations to repay debt, withdraw collateral, and transfer assets
     * @param oldVault Address of the vault to withdraw from
     * @param newVault Address of the vault to transfer assets to
     * @param lendAsset Address of the asset being lent to Aave
     * @param borrowAsset Address of the asset being borrowed from Aave
     * @param borrowBalance Amount of borrowed asset to repay
     * @param lendBalance Amount of lent asset to withdraw
     * @return moduleExecutionData Array of module operations to execute
     */
    function _perpareWithdrawCalls(
        address oldVault,
        address newVault,
        address lendAsset,
        address borrowAsset,
        uint256 borrowBalance,
        uint256 lendBalance
    ) internal returns (DataTypes.ModuleExecutionData[] memory) {
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);

        // Step 1: Repay the borrowed asset using flash loan funds
        DataTypes.AaveV3ActionParams memory repayParams =
            DataTypes.AaveV3ActionParams({asset: borrowAsset, amount: borrowBalance});
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(repayModule),
            data: abi.encodeWithSelector(repayModule.execute.selector, repayParams)
        });

        // Step 2: Withdraw the lent asset from Aave
        DataTypes.AaveV3ActionParams memory withdrawParams =
            DataTypes.AaveV3ActionParams({asset: lendAsset, amount: lendBalance});
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(withdrawModule),
            data: abi.encodeWithSelector(withdrawModule.execute.selector, withdrawParams)
        });

        // Step 3: Transfer all assets from old vault to new vault via DEX module
        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: lendAsset,
            data: abi.encodeWithSelector(IERC20.transfer.selector, address(newVault), lendBalance)
        });
        uint256 xtzBalanceOldVault = IERC20(borrowAsset).balanceOf(oldVault);
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: borrowAsset,
            data: abi.encodeWithSelector(IERC20.transfer.selector, address(newVault), xtzBalanceOldVault)
        });

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: placeholderAsset,
            tokenOut: placeholderAsset,
            amountIn: lendBalance,
            maxAmountIn: type(uint256).max,
            minAmountOut: 0,
            data: swapParamsData
        });

        moduleExecutionData[2] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });

        // Transfer flash loaned asset to old vault for repayment
        IERC20(borrowAsset).transfer(oldVault, borrowBalance);

        return moduleExecutionData;
    }

    /**
     * @notice Prepares module execution data for depositing assets into the new vault
     * @dev Creates operations to deposit collateral, borrow debt, and transfer repayment funds
     * @param lendAsset Address of the asset being lent to Aave
     * @param borrowAsset Address of the asset being borrowed from Aave
     * @param borrowBalance Amount of borrowed asset (includes flash loan premium)
     * @param lendBalance Amount of lent asset to deposit
     * @return moduleExecutionData Array of module operations to execute
     */
    function _perpareDepositCalls(address lendAsset, address borrowAsset, uint256 borrowBalance, uint256 lendBalance)
        internal
        view
        returns (DataTypes.ModuleExecutionData[] memory)
    {
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);

        // Step 1: Deposit the lent asset to Aave via new vault
        DataTypes.AaveV3ActionParams memory depositParams =
            DataTypes.AaveV3ActionParams({asset: lendAsset, amount: lendBalance});
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(depositModule),
            data: abi.encodeWithSelector(depositModule.execute.selector, depositParams)
        });

        // Step 2: Borrow the required amount (including flash loan premium) from Aave
        DataTypes.AaveV3ActionParams memory borrowParams =
            DataTypes.AaveV3ActionParams({asset: borrowAsset, amount: borrowBalance});
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(borrowModule),
            data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
        });

        // Step 3: Transfer borrowed asset back to migration helper for flash loan repayment
        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](1);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: borrowAsset,
            data: abi.encodeWithSelector(IERC20.transfer.selector, address(this), borrowBalance)
        });
        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: placeholderAsset,
            tokenOut: placeholderAsset,
            amountIn: lendBalance,
            maxAmountIn: type(uint256).max,
            minAmountOut: 0,
            data: swapParamsData
        });

        moduleExecutionData[2] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });

        return moduleExecutionData;
    }
}
