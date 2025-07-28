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

/**
 * @title UniversalDexModule
 * @author Superlend
 * @notice Universal DEX module for executing token swaps across multiple DEX protocols
 * @dev Provides flexible swap execution with balance validation and reentrancy protection
 */
contract UniversalDexModule is ReentrancyGuard, Context {
    /**
     * @notice Emitted when a swap is executed
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param amountIn The amount of input tokens swapped
     * @param amountOut The amount of output tokens received
     */
    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Executes a token swap within the execution context
     * @param params The swap execution parameters
     * @return The amount of output tokens received
     */
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

    /**
     * @notice Executes a token swap and transfers the result to a specified address
     * @param params The swap execution parameters
     * @param to The address to receive the swapped tokens (if zero, uses msg.sender)
     * @return The amount of output tokens received
     */
    function executeAndExit(DataTypes.ExecuteSwapParams memory params, address to)
        external
        nonReentrant
        returns (uint256)
    {
        address self = address(this);
        to = to == address(0) ? _msgSender() : to;

        SafeERC20.safeTransferFrom(IERC20(params.tokenIn), _msgSender(), address(this), params.amountIn);

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

        if (diffInTokenOutBalance > 0) {
            SafeERC20.safeTransfer(IERC20(params.tokenOut), to, diffInTokenOutBalance);
        }

        if (diffInTokenInBalance > 0) {
            SafeERC20.safeTransfer(IERC20(params.tokenIn), to, diffInTokenInBalance);
        }

        emit SwapExecuted(params.tokenIn, params.tokenOut, diffInTokenInBalance, diffInTokenOutBalance);
        return diffInTokenOutBalance;
    }

    /**
     * @notice Internal function to execute the actual swap operations
     * @param params The swap execution parameters containing target contracts and data
     */
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

    /**
     * @notice Modifier to ensure the function is called within an execution context
     * @dev Reverts if not in execution context
     */
    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    /**
     * @notice Internal function to check if the current call is within an execution context
     * @return True if in execution context, false otherwise
     */
    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
