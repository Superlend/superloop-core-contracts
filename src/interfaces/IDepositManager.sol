// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IDepositManager
 * @author Superlend
 * @notice Interface for deposit manager operations
 * @dev Handles deposit request creation and management
 */
interface IDepositManager {
    /**
     * @notice Creates a deposit request for the specified amount
     * @param amount The amount of assets to deposit
     * @param onBehalfOf The address to deposit on behalf of
     */
    function requestDeposit(uint256 amount, address onBehalfOf) external;
}
