// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IWithdrawManagerCallbackHandler
 * @author Superlend
 * @notice Interface for withdraw manager callback handler operations
 * @dev Handles withdrawal execution callbacks with custom parameters
 */
interface IWithdrawManagerCallbackHandler {
    /**
     * @notice Executes a withdrawal operation with custom parameters
     * @param amount The amount to withdraw
     * @param params Additional parameters for the withdrawal execution
     * @return True if the withdrawal was successful, false otherwise
     */
    function executeWithdraw(uint256 amount, bytes calldata params) external returns (bool);
}
