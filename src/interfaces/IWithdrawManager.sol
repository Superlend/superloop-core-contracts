// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title IWithdrawManager
 * @author Superlend
 * @notice Interface for managing withdrawal requests and operations
 * @dev Handles withdrawal request lifecycle from creation to resolution
 */
interface IWithdrawManager {
    /**
     * @notice Emitted when a withdrawal request is created
     * @param user The address of the user making the withdrawal request
     * @param shares The number of shares being withdrawn
     * @param amount The amount of underlying asset being withdrawn
     * @param id The unique identifier for the withdrawal request
     */
    event WithdrawRequest(address indexed user, uint256 shares, uint256 amount, uint256 id);

    /**
     * @notice Creates a new withdrawal request for the specified number of shares
     * @param shares The number of shares to withdraw
     */
    function requestWithdraw(uint256 shares) external;

    /**
     * @notice Resolves withdrawal requests up to the specified limit
     * @param resolvedIdLimit The maximum number of withdrawal requests to resolve
     */
    function resolveWithdrawRequests(uint256 resolvedIdLimit) external;

    /**
     * @notice Executes the withdrawal for resolved requests
     */
    function withdraw() external;

    /**
     * @notice Cancels a specific withdrawal request
     * @param id The unique identifier of the withdrawal request to cancel
     */
    function cancelWithdrawRequest(uint256 id) external;

    /**
     * @notice Gets the current state of a withdrawal request
     * @param id The unique identifier of the withdrawal request
     * @return The current state of the withdrawal request
     */
    function getWithdrawRequestState(uint256 id) external view returns (DataTypes.WithdrawRequestStateLegacy);

    /**
     * @notice Gets the address of the associated vault
     * @return The vault address
     */
    function vault() external view returns (address);

    /**
     * @notice Gets the address of the underlying asset
     * @return The asset address
     */
    function asset() external view returns (address);

    /**
     * @notice Gets the next withdrawal request ID to be assigned
     * @return The next withdrawal request ID
     */
    function nextWithdrawRequestId() external view returns (uint256);

    /**
     * @notice Gets the ID of the last resolved withdrawal request
     * @return The last resolved withdrawal request ID
     */
    function resolvedWithdrawRequestId() external view returns (uint256);

    /**
     * @notice Gets the data for a specific withdrawal request
     * @param id The unique identifier of the withdrawal request
     * @return The withdrawal request data
     */
    function withdrawRequest(uint256 id) external view returns (DataTypes.WithdrawRequestDataLegacy memory);

    /**
     * @notice Gets the data for multiple withdrawal requests
     * @param ids Array of withdrawal request IDs
     * @return Array of withdrawal request data
     */
    function withdrawRequests(uint256[] memory ids) external view returns (DataTypes.WithdrawRequestDataLegacy[] memory);

    /**
     * @notice Gets the withdrawal request ID for a specific user
     * @param user The address of the user
     * @return The withdrawal request ID for the user
     */
    function userWithdrawRequestId(address user) external view returns (uint256);
}
