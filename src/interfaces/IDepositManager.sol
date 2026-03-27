// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title IDepositManager
 * @author Superlend
 * @notice Interface for deposit manager operations
 * @dev Handles deposit request creation and management
 */
interface IDepositManager {
    /// @notice Emitted when a user creates a new deposit request.
    /// @param user Address that initiated the request.
    /// @param amount Asset amount requested for deposit.
    /// @param requestId Unique id assigned to the deposit request.
    event DepositRequested(address indexed user, uint256 amount, uint256 requestId);
    /// @notice Emitted when a pending deposit request is cancelled.
    /// @param requestId Id of the cancelled request.
    /// @param user Owner of the cancelled request.
    /// @param amountRefunded Asset amount returned to the user.
    event DepositRequestCancelled(uint256 indexed requestId, address indexed user, uint256 amountRefunded);

    /// @notice Creates a new deposit request for `onBehalfOf`.
    /// @param amount Asset amount to queue for deposit.
    /// @param onBehalfOf Beneficiary that owns the queued request.
    function requestDeposit(uint256 amount, address onBehalfOf) external;

    /// @notice Cancels a pending deposit request and refunds assets.
    /// @param id Id of the request to cancel.
    function cancelDepositRequest(uint256 id) external;

    /// @notice Resolves a batch of queued deposit requests.
    /// @param data Resolution payload containing ids and accounting inputs.
    function resolveDepositRequests(DataTypes.ResolveDepositRequestsData memory data) external;

    /// @notice Returns the vault address linked to this manager.
    function vault() external view returns (address);

    /// @notice Returns the underlying asset accepted for deposits.
    function asset() external view returns (address);

    /// @notice Returns the next deposit request id to be assigned.
    function nextDepositRequestId() external view returns (uint256);

    /// @notice Returns the request data for a specific deposit id.
    /// @param id Deposit request id.
    function depositRequest(uint256 id) external view returns (DataTypes.DepositRequestData memory);

    /// @notice Returns request data for a batch of deposit ids.
    /// @param ids Deposit request ids to fetch.
    function depositRequests(uint256[] memory ids) external view returns (DataTypes.DepositRequestData[] memory);

    /// @notice Returns the latest request owned by a user and its id.
    /// @param user Address whose request is queried.
    function userDepositRequest(address user) external view returns (DataTypes.DepositRequestData memory, uint256);

    /// @notice Returns total assets currently pending in deposit queue.
    function totalPendingDeposits() external view returns (uint256);

    /// @notice Returns the current resolution cursor in the queue.
    function resolutionIdPointer() external view returns (uint256);

    /// @notice Returns decimal offset used for share/asset conversion.
    function vaultDecimalOffset() external view returns (uint8);
}
