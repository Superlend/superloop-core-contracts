// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title DataTypes
 * @author Superlend
 * @notice Library containing all data structures and enums used throughout the Superloop protocol
 * @dev Centralized data type definitions for consistent usage across contracts
 */
library DataTypes {
    /**
     * @notice Structure for storing module information
     * @param moduleName The name identifier of the module
     * @param moduleAddress The contract address of the module
     */
    struct ModuleData {
        string moduleName;
        address moduleAddress;
    }

    struct ExchangeRateSnapshot {
        uint256 totalSupplyBefore;
        uint256 totalSupplyAfter;
        uint256 totalAssetsBefore;
        uint256 totalAssetsAfter;
    }

    enum RequestProcessingState {
        NOT_EXIST,
        UNPROCESSED,
        PARTIALLY_PROCESSED, // partially processed means that the deposit request has been partially processed
        PARTIALLY_CANCELLED, // partially cancelled means that the deposit request has been partially cancelled
        FULLY_PROCESSED,
        CANCELLED
    }

    struct DepositRequestData {
        uint256 amount;
        uint256 amountProcessed; // amoutn remaining => amount - amountProcessed
        uint256 sharesMinted;
        address user;
        RequestProcessingState state;
    }

    struct ResolveDepositRequestsData {
        address asset;
        uint256 amount;
        bytes callbackExecutionData;
    }

    enum WithdrawRequestType {
        GENERAL, // general queue
        DEFERRED, // low slippage queue
        PRIORITY, // medium slippage queue
        INSTANT // high slippage queue

    }

    struct WithdrawQueue {
        uint256 nextWithdrawRequestId;
        uint256 resolutionIdPointer;
        mapping(uint256 => DataTypes.WithdrawRequestData) withdrawRequest;
        mapping(address => uint256) userWithdrawRequestId;
        uint256 totalPendingWithdraws;
    }

    struct WithdrawRequestData {
        uint256 shares;
        uint256 sharesProcessed;
        uint256 amountClaimable;
        uint256 amountClaimed;
        address user;
        RequestProcessingState state;
    }

    struct ResolveWithdrawRequestsData {
        uint256 shares;
        WithdrawRequestType requestType;
        bytes callbackExecutionData;
    }

    /**
     * @notice Structure for storing withdrawal request information
     * @param shares The number of shares requested for withdrawal
     * @param amount The amount of underlying asset for withdrawal
     * @param user The address of the user making the withdrawal request
     * @param claimed Whether the withdrawal has been claimed
     * @param cancelled Whether the withdrawal request has been cancelled
     */
    struct WithdrawRequestDataLegacy {
        uint256 shares;
        uint256 amount;
        address user;
        bool claimed;
        bool cancelled;
    }

    /**
     * @notice Enumeration of possible withdrawal request states
     */
    enum WithdrawRequestStateLegacy {
        NOT_EXIST, // Request does not exist
        CLAIMED, // Request has been claimed
        UNPROCESSED, // Request is pending processing
        CLAIMABLE, // Request is ready to be claimed
        CANCELLED // Request has been cancelled

    }

    /**
     * @notice Structure for vault initialization data
     * @param asset The address of the underlying asset
     * @param name The name of the vault
     * @param symbol The symbol of the vault
     * @param supplyCap The maximum supply cap for the vault
     * @param minimumDepositAmount The minimum deposit amount for the vault
     * @param instantWithdrawFee The instant withdraw fee for the vault
     * @param superloopModuleRegistry The address of the module registry
     * @param modules Array of module addresses to register
     * @param cashReserve The amount of cash reserve for the vault. Represented in BPS
     * @param accountant The address of the accountant module
     * @param withdrawManager The address of the withdraw manager module
     * @param vaultAdmin The address of the vault admin
     * @param treasury The address of the treasury
     * @param vaultOperator The address of the vault operator
     */
    struct VaultInitData {
        // vault specific
        address asset;
        string name;
        string symbol;
        // superloop specific
        uint256 supplyCap;
        uint256 minimumDepositAmount;
        uint256 instantWithdrawFee;
        address superloopModuleRegistry;
        address[] modules;
        uint256 cashReserve;
        // essential roles
        address accountant;
        address withdrawManager;
        address depositManager;
        address vaultAdmin;
        address treasury;
        address vaultOperator;
    }

    /**
     * @notice Structure for universal DEX module swap execution data
     * @param target The target contract address for the swap
     * @param data The encoded function call data
     */
    struct ExecuteSwapParamsData {
        address target;
        bytes data;
    }

    /**
     * @notice Structure for complete swap execution parameters
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param amountIn The amount of input tokens
     * @param maxAmountIn The maximum amount of input tokens allowed
     * @param minAmountOut The minimum amount of output tokens expected
     * @param data Array of swap execution data for multi-step swaps
     */
    struct ExecuteSwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 maxAmountIn;
        uint256 minAmountOut;
        ExecuteSwapParamsData[] data;
    }

    /**
     * @notice Structure for tracking balance differences before and after operations
     * @param tokenInBalanceBefore Balance of input token before operation
     * @param tokenOutBalanceBefore Balance of output token before operation
     * @param tokenInBalanceAfter Balance of input token after operation
     * @param tokenOutBalanceAfter Balance of output token after operation
     */
    struct BalancesDifference {
        uint256 tokenInBalanceBefore;
        uint256 tokenOutBalanceBefore;
        uint256 tokenInBalanceAfter;
        uint256 tokenOutBalanceAfter;
    }

    /**
     * @notice Structure for Aave V3 accountant module initialization
     * @param poolAddressesProvider The Aave pool addresses provider
     * @param lendAssets Array of assets available for lending
     * @param borrowAssets Array of assets available for borrowing
     * @param performanceFee The performance fee percentage
     * @param vault The address of the associated vault
     */
    struct AaveV3AccountantModuleInitData {
        address poolAddressesProvider;
        address[] lendAssets;
        address[] borrowAssets;
        uint16 performanceFee;
        address vault;
    }

    /**
     * @notice Structure for module execution data
     * @param executionType The type of call to execute (CALL or DELEGATECALL)
     * @param module The address of the module to execute
     * @param data The encoded function call data
     */
    struct ModuleExecutionData {
        CallType executionType;
        address module;
        bytes data;
    }

    /**
     * @notice Enumeration of call types for module execution
     */
    enum CallType {
        CALL, // Regular call to external contract
        DELEGATECALL // Delegate call to external contract

    }

    /**
     * @notice Structure for Aave V3 flashloan parameters
     * @param asset The address of the asset to flashloan
     * @param amount The amount to flashloan
     * @param referralCode The referral code for Aave
     * @param callbackExecutionData The data to execute in the flashloan callback
     */
    struct AaveV3FlashloanParams {
        address asset;
        uint256 amount;
        uint16 referralCode;
        bytes callbackExecutionData;
    }

    /**
     * @notice Structure for callback execution data
     * @param asset The address of the asset involved
     * @param addressToApprove The address to approve tokens for
     * @param amountToApprove The amount to approve
     * @param executionData The data to execute in the callback
     */
    struct CallbackData {
        address asset;
        address addressToApprove;
        uint256 amountToApprove;
        bytes executionData;
    }

    /**
     * @notice Structure for Aave V3 eMode parameters
     * @param emodeCategory The eMode category to set
     */
    struct AaveV3EmodeParams {
        uint8 emodeCategory;
    }

    /**
     * @notice Structure for Aave V3 action parameters
     * @param asset The address of the asset
     * @param amount The amount of the asset
     */
    struct AaveV3ActionParams {
        address asset;
        uint256 amount;
    }

    /**
     * @notice Structure for Aave V3 accountant module initialization
     * @param registeredAccountants Array of registered accountant addresses
     * @param performanceFee The performance fee percentage
     * @param vault The address of the associated vault
     */
    struct UniversalAccountantModuleInitData {
        address[] registeredAccountants;
        uint16 performanceFee;
        address vault;
    }

    /**
     * @notice Structure for Aave V3 accountant plugin module initialization
     * @param poolAddressesProvider The Aave pool addresses provider
     * @param lendAssets Array of assets available for lending
     * @param borrowAssets Array of assets available for borrowing
     */
    struct AaveV3AccountantPluginModuleInitData {
        address poolAddressesProvider;
        address[] lendAssets;
        address[] borrowAssets;
    }

    /**
     * @notice Structure for stake parameters
     * @param assets The amount of assets to stake
     * @param data Any additional data to pass to the stake module
     */
    struct StakeParams {
        uint256 assets;
        bytes data;
    }

    enum DepositType {
        INSTANT,
        REQUESTED
    }

    /**
     * @notice Structure for Aave V3 preliquidation parameters
     * @param user The address of the user
     * @param debtToCover The amount of debt to cover
     */
    struct AaveV3ExecutePreliquidationParams {
        address user;
        uint256 debtToCover;
    }

    /**
     * @notice Structure for Aave V3 preliquidation initialization parameters
     * @param id The id of the preliquidation contract, used to make sure fallback handler is configured correctly
     * @param lendReserve The address of the lend reserve
     * @param borrowReserve The address of the borrow reserve
     * @param preLltv The preliquidation ltv
     * @param preCF1 The preliquidation c1
     * @param preCF2 The preliquidation c2
     * @param preIF1 The preliquidation i1
     * @param preIF2 The preliquidation i2
     */
    struct AaveV3PreliquidationParamsInit {
        bytes32 id;
        address lendReserve;
        address borrowReserve;
        uint256 preLltv;
        uint256 preCF1;
        uint256 preCF2;
        uint256 preIF1;
        uint256 preIF2;
    }

    /**
     * @notice Structure for Aave V3 preliquidation parameters
     * @param lendReserve The address of the lend reserve
     * @param borrowReserve The address of the borrow reserve
     * @param Lltv The ltv
     * @param preLltv The preliquidation ltv
     * @param preCF1 The preliquidation c1
     * @param preCF2 The preliquidation c2
     * @param preIF1 The preliquidation i1
     * @param preIF2 The preliquidation i2
     */
    struct AaveV3PreliquidationParams {
        address lendReserve;
        address borrowReserve;
        uint256 Lltv;
        uint256 preLltv;
        uint256 preCF1;
        uint256 preCF2;
        uint256 preIF1;
        uint256 preIF2;
    }

    /**
     * @notice Structure for Merkl claim parameters
     * @param users The addresses of the users to claim rewards for
     * @param tokens The addresses of the tokens to claim rewards for
     * @param amounts The amounts of the tokens to claim rewards for
     * @param proofs The proofs of the Merkle tree
     */
    struct MerklClaimParams {
        address[] users;
        address[] tokens;
        uint256[] amounts;
        bytes32[][] proofs;
    }

    /**
     * @notice Structure for vault action parameters
     * @param vault The address of the vault
     * @param amount The amount of the vault to supply
     */
    struct VaultActionParams {
        address vault;
        uint256 amount;
    }
}
