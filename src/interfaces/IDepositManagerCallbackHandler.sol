// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IDepositManagerCallbackHandler
 * @author Superlend
 * @notice Interface for deposit manager callback handler operations
 * @dev Handles deposit execution callbacks with custom parameters
 */
interface IDepositManagerCallbackHandler {
    /**
     * @notice Executes a deposit operation with custom parameters
     * @param amount The amount to deposit
     * @param params Additional parameters for the deposit execution
     * @return True if the deposit was successful, false otherwise
     */
    function executeDeposit(uint256 amount, bytes calldata params) external returns (bool);
}
