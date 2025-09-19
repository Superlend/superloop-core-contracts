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
        address user;
        RequestProcessingState state;
    }

    struct ResolveDepositRequestsData {
        address asset;
        uint256 amount;
        bytes callbackExecutionData;
    }

    struct WithdrawRequestData {
        uint256 shares;
        uint256 sharesProcessed;
        uint256 amountClaimable;
        uint256 amountClaimed;
        address user;
        RequestProcessingState state;
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
     * @param superloopModuleRegistry The address of the module registry
     * @param modules Array of module addresses to register
     * @param cashReserve The amount of cash reserve for the vault. Represented in BPS
     * @param accountantModule The address of the accountant module
     * @param withdrawManagerModule The address of the withdraw manager module
     * @param vaultAdmin The address of the vault admin
     * @param treasury The address of the treasury
     */
    struct VaultInitData {
        // vault specific
        address asset;
        string name;
        string symbol;
        // superloop specific
        uint256 supplyCap;
        address superloopModuleRegistry;
        address[] modules;
        uint256 cashReserve;
        // essential roles
        address accountantModule;
        address withdrawManagerModule;
        address depositManager;
        address vaultAdmin;
        address treasury;
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
}
