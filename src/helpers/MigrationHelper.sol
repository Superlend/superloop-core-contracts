// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {ISuperloop} from "../interfaces/ISuperloop.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {AaveV3ActionModule} from "../modules/AaveV3ActionModule.sol";
import {UniversalDexModule} from "../modules/UniversalDexModule.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract MigrationHelper is FlashLoanSimpleReceiverBase, Ownable {
    struct VaultStateData {
        uint256 totalSupply;
        uint256 totalAssets;
        uint256[] balances;
        uint256 borrowBalance;
        uint256 lendBalance;
    }

    IPoolDataProvider immutable poolDataProvider;
    uint256 immutable commonDecimalFactor;

    AaveV3ActionModule immutable repayModule;
    AaveV3ActionModule immutable withdrawModule;
    AaveV3ActionModule immutable depositModule;
    AaveV3ActionModule immutable borrowModule;
    UniversalDexModule immutable dexModule;
    address immutable placeholderAsset;
    bool public DEV;

    constructor(
        bool _DEV,
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
        DEV = _DEV;
        repayModule = AaveV3ActionModule(_repayModule);
        withdrawModule = AaveV3ActionModule(_withdrawModule);
        depositModule = AaveV3ActionModule(_depositModule);
        borrowModule = AaveV3ActionModule(_borrowModule);
        dexModule = UniversalDexModule(_dexModule);
        placeholderAsset = _placeholderAsset;
    }

    function migrate(
        address oldVault,
        address newVault,
        address[] calldata users,
        address lendAsset,
        address borrowAsset
    ) external returns (bool) {
        address blackListedUser = ISuperloop(oldVault).withdrawManagerModule();
        uint256 blackListedUserBalance = ISuperloop(oldVault).balanceOf(blackListedUser);
        console.log("blackListedUserBalance", blackListedUserBalance);
        if (blackListedUserBalance > 0) {
            revert("withdraw manager must be empty");
        }

        // get current total supply
        // match balance of each of the user, it should match exactly with the total supply
        // get current exchange rate
        VaultStateData memory oldVaultState = _getVaultState(oldVault, users, lendAsset, borrowAsset);
        if (!DEV) {
            _validateUserBalancesWithTotalSupply(oldVaultState);
        }

        //---------------------------------------------------------------------------
        // do the migration flow
        //---------------------------------------------------------------------------
        _initiateMigration(oldVault, lendAsset, borrowAsset, oldVaultState, newVault);

        // mint each of the user's share
        for (uint256 i = 0; i < users.length; i++) {
            ISuperloop(newVault).mintShares(users[i], oldVaultState.balances[i]);
        }
        // get new vault's total supply
        // get new vault's each users balance
        VaultStateData memory newVaultState = _getVaultState(newVault, users, lendAsset, borrowAsset);

        if (!DEV) {
            _validateUserBalancesWithTotalSupply(newVaultState);
        } else {
            uint256 sharesToMint = oldVaultState.totalSupply - ISuperloop(newVault).totalSupply();
            // temp: will be removed, added for testing to observe the change in exchange rate
            ISuperloop(newVault).mintShares(blackListedUser, sharesToMint);
            newVaultState.totalSupply = ISuperloop(newVault).totalSupply();
        }

        uint256 oldExchangeRate = (oldVaultState.totalAssets * commonDecimalFactor) / oldVaultState.totalSupply;
        uint256 newExchangeRate = (newVaultState.totalAssets * commonDecimalFactor) / newVaultState.totalSupply;
        uint256 diff =
            oldExchangeRate > newExchangeRate ? oldExchangeRate - newExchangeRate : newExchangeRate - oldExchangeRate;
        uint256 percentageChangeInExchangeRate = (diff * 10000) / oldExchangeRate;

        console.log("percentageChangeInExchangeRate", percentageChangeInExchangeRate);

        require(percentageChangeInExchangeRate <= 5, "Exchange rates do not match"); // 0.05% change in exchange rate is allowed

        return true;
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address, bytes calldata params)
        external
        returns (bool)
    {
        require(msg.sender == address(POOL), "Only pool can call flashloan callback");

        // decode params

        (
            address oldVault,
            uint256 oldVaultLendBalance,
            uint256 oldVaultBorrowBalance,
            address lendAsset,
            address borrowAsset,
            address newVault
        ) = abi.decode(params, (address, uint256, uint256, address, address, address));

        _executeMigration(
            oldVault, newVault, lendAsset, borrowAsset, oldVaultBorrowBalance, oldVaultLendBalance, premium
        );

        // approve pool to pull the amount
        SafeERC20.forceApprove(IERC20(asset), address(POOL), amount + premium);
        return true;
    }

    function _getVaultState(address vaultAddress, address[] calldata users, address lendAsset, address borrowAsset)
        internal
        view
        returns (VaultStateData memory)
    {
        ISuperloop vault = ISuperloop(vaultAddress);
        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();
        uint256[] memory balances = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            balances[i] = vault.balanceOf(users[i]);
        }

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

    function _validateUserBalancesWithTotalSupply(VaultStateData memory vaultState) internal pure {
        uint256 calculatedTotalSupply = 0;
        for (uint256 i = 0; i < vaultState.balances.length; i++) {
            calculatedTotalSupply += vaultState.balances[i];
        }
        require(calculatedTotalSupply == vaultState.totalSupply, "Calculated total supply does not match total supply");
    }

    function _initiateMigration(
        address oldVault,
        address lendAsset,
        address borrowAsset,
        VaultStateData memory oldVaultState,
        address newVault
    ) internal {
        bytes memory callbackData = abi.encode(
            oldVault, oldVaultState.lendBalance, oldVaultState.borrowBalance, lendAsset, borrowAsset, newVault
        );

        POOL.flashLoanSimple(address(this), borrowAsset, oldVaultState.borrowBalance, callbackData, 0);
    }

    function _executeMigration(
        address oldVault,
        address newVault,
        address lendAsset,
        address borrowAsset,
        uint256 borrowBalance,
        uint256 lendBalance,
        uint256 premium
    ) internal {
        DataTypes.ModuleExecutionData[] memory moduleExecutionDataWithdraw =
            _perpareWithdrawCalls(oldVault, newVault, lendAsset, borrowAsset, borrowBalance, lendBalance);

        ISuperloop(oldVault).operate(moduleExecutionDataWithdraw);

        DataTypes.ModuleExecutionData[] memory moduleExecutionDataDeposit =
            _perpareDepositCalls(lendAsset, borrowAsset, borrowBalance + premium, lendBalance);

        ISuperloop(newVault).operate(moduleExecutionDataDeposit);
    }

    function _perpareWithdrawCalls(
        address oldVault,
        address newVault,
        address lendAsset,
        address borrowAsset,
        uint256 borrowBalance,
        uint256 lendBalance
    ) internal returns (DataTypes.ModuleExecutionData[] memory) {
        // take a flashloan of net amount of xtz borrowed
        // build an operate call
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        // repay the xtz borrowed
        DataTypes.AaveV3ActionParams memory repayParams =
            DataTypes.AaveV3ActionParams({asset: borrowAsset, amount: borrowBalance});
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(repayModule),
            data: abi.encodeWithSelector(repayModule.execute.selector, repayParams)
        });

        // withdraw the stXTZ
        DataTypes.AaveV3ActionParams memory withdrawParams =
            DataTypes.AaveV3ActionParams({asset: lendAsset, amount: lendBalance});
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(withdrawModule),
            data: abi.encodeWithSelector(withdrawModule.execute.selector, withdrawParams)
        });

        // send the xtz and stXTZ lying in the vault to the new vault via dex module
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

        // send the xtz to the vault
        IERC20(borrowAsset).transfer(oldVault, borrowBalance);

        return moduleExecutionData;
    }

    function _perpareDepositCalls(address lendAsset, address borrowAsset, uint256 borrowBalance, uint256 lendBalance)
        internal
        view
        returns (DataTypes.ModuleExecutionData[] memory)
    {
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);

        // deposit stXTZ via the new vault
        DataTypes.AaveV3ActionParams memory depositParams =
            DataTypes.AaveV3ActionParams({asset: lendAsset, amount: lendBalance});
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(depositModule),
            data: abi.encodeWithSelector(depositModule.execute.selector, depositParams)
        });

        // borrow xtz + premium via the new vault
        DataTypes.AaveV3ActionParams memory borrowParams =
            DataTypes.AaveV3ActionParams({asset: borrowAsset, amount: borrowBalance});
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(borrowModule),
            data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
        });

        // send the borrowed token back to migration helper for flash loan repayment
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
