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
        address feeManager;
        address withdrawManager;
        address commonPriceOracle;
        // management specific
        address vaultAdmin;
        address treasury;
        uint16 performanceFee; // BPS
        address[] modules;
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
}
