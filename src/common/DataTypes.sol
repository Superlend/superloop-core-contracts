// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library DataTypes {
    struct ModuleData {
        string moduleName;
        address moduleAddress;
    }

    struct WithdrawRequestData {
        uint256 shares;
        uint256 amount;
        address user;
        bool claimed;
        bool cancelled;
    }

    enum WithdrawRequestState {
        NOT_EXIST,
        CLAIMED,
        UNPROCESSED,
        CLAIMABLE,
        CANCELLED
    }

    struct VaultInitData {
        // vault specific
        address asset;
        string name;
        string symbol;
        // superloop specific
        uint256 supplyCap;
        address superloopModuleRegistry;
        address[] modules;
        // essential roles
        address accountantModule;
        address withdrawManagerModule;
        address vaultAdmin;
        address treasury;
    }

    // UniversalDexModule data types
    struct ExecuteSwapParamsData {
        address target;
        bytes data;
    }

    struct ExecuteSwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 maxAmountIn;
        uint256 minAmountOut;
        ExecuteSwapParamsData[] data;
    }

    struct BalancesDifference {
        uint256 tokenInBalanceBefore;
        uint256 tokenOutBalanceBefore;
        uint256 tokenInBalanceAfter;
        uint256 tokenOutBalanceAfter;
    }

    struct AaveV3AccountantModuleInitData {
        address poolAddressesProvider;
        address[] lendAssets;
        address[] borrowAssets;
        uint16 performanceFee;
        address vault;
    }

    struct ModuleExecutionData {
        CallType executionType;
        address module;
        bytes data;
    }

    enum CallType {
        CALL,
        DELEGATECALL
    }

    struct AaveV3FlashloanParams {
        address asset;
        uint256 amount;
        uint16 referralCode;
        bytes callbackExecutionData;
    }

    struct CallbackData {
        address asset;
        address addressToApprove;
        uint256 amountToApprove;
        bytes executionData;
    }
}
