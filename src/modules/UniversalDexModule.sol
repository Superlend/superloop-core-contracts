// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {SuperloopStorage} from "../core/lib/SuperloopStorage.sol";
import {Errors} from "../common/Errors.sol";
import {DataTypes} from "../common/DataTypes.sol";

contract UniversalDexModule is ReentrancyGuard, Context {
    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    function execute(DataTypes.ExecuteSwapParams memory params) external onlyExecutionContext returns (uint256) {
        address self = address(this);

        DataTypes.BalancesDifference memory balances = DataTypes.BalancesDifference({
            tokenInBalanceBefore: IERC20(params.tokenIn).balanceOf(self),
            tokenOutBalanceBefore: IERC20(params.tokenOut).balanceOf(self),
            tokenInBalanceAfter: 0,
            tokenOutBalanceAfter: 0
        });

        _executeSwap(params);

        balances.tokenInBalanceAfter = IERC20(params.tokenIn).balanceOf(self);
        balances.tokenOutBalanceAfter = IERC20(params.tokenOut).balanceOf(self);

        uint256 diffInTokenInBalance = balances.tokenInBalanceBefore - balances.tokenInBalanceAfter;
        require(diffInTokenInBalance <= params.maxAmountIn, Errors.INVALID_AMOUNT_IN);

        uint256 diffInTokenOutBalance = balances.tokenOutBalanceAfter - balances.tokenOutBalanceBefore;
        require(diffInTokenOutBalance >= params.minAmountOut, Errors.INVALID_AMOUNT_OUT);

        emit SwapExecuted(params.tokenIn, params.tokenOut, diffInTokenInBalance, diffInTokenOutBalance);
        return diffInTokenOutBalance;
    }

    function executeAndExit(DataTypes.ExecuteSwapParams memory params, address to)
        external
        nonReentrant
        returns (uint256)
    {
        address self = address(this);
        to = to == address(0) ? _msgSender() : to;

        DataTypes.BalancesDifference memory balances = DataTypes.BalancesDifference({
            tokenInBalanceBefore: IERC20(params.tokenIn).balanceOf(self),
            tokenOutBalanceBefore: IERC20(params.tokenOut).balanceOf(self),
            tokenInBalanceAfter: 0,
            tokenOutBalanceAfter: 0
        });

        SafeERC20.safeTransferFrom(IERC20(params.tokenIn), _msgSender(), address(this), params.amountIn);

        _executeSwap(params);

        balances.tokenInBalanceAfter = IERC20(params.tokenIn).balanceOf(self);
        balances.tokenOutBalanceAfter = IERC20(params.tokenOut).balanceOf(self);

        uint256 diffInTokenInBalance = balances.tokenInBalanceBefore - balances.tokenInBalanceAfter;
        require(diffInTokenInBalance <= params.maxAmountIn, Errors.INVALID_AMOUNT_IN);

        uint256 diffInTokenOutBalance = balances.tokenOutBalanceAfter - balances.tokenOutBalanceBefore;
        require(diffInTokenOutBalance >= params.minAmountOut, Errors.INVALID_AMOUNT_OUT);

        if (diffInTokenOutBalance > 0) {
            SafeERC20.safeTransfer(IERC20(params.tokenOut), to, diffInTokenOutBalance);
        }

        if (diffInTokenInBalance > 0) {
            SafeERC20.safeTransfer(IERC20(params.tokenIn), to, diffInTokenInBalance);
        }

        emit SwapExecuted(params.tokenIn, params.tokenOut, diffInTokenInBalance, diffInTokenOutBalance);
        return diffInTokenOutBalance;
    }

    function _executeSwap(DataTypes.ExecuteSwapParams memory params) internal {
        require(params.data.length > 0, Errors.INVALID_SWAP_DATA);

        uint256 len = params.data.length;
        for (uint256 i; i < len;) {
            Address.functionCall(params.data[i].target, params.data[i].data);

            unchecked {
                ++i;
            }
        }
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
