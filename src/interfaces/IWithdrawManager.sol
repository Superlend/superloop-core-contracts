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
    /// @notice Emitted when a user creates a new withdrawal request.
    /// @param user Address that initiated the request.
    /// @param shares Share amount queued for withdrawal.
    /// @param requestId Unique id assigned to the withdraw request.
    /// @param requestType Withdraw lane used by the request.
    event WithdrawRequested(
        address indexed user, uint256 shares, uint256 requestId, DataTypes.WithdrawRequestType requestType
    );
    /// @notice Emitted when a pending withdrawal request is cancelled.
    /// @param requestId Id of the cancelled request.
    /// @param user Owner of the cancelled request.
    /// @param sharesRefunded Shares returned to the user.
    /// @param assetsClaimed Assets delivered during cancellation if applicable.
    /// @param requestType Withdraw lane of the cancelled request.
    event WithdrawRequestCancelled(
        uint256 indexed requestId,
        address indexed user,
        uint256 sharesRefunded,
        uint256 assetsClaimed,
        DataTypes.WithdrawRequestType requestType
    );
    /// @notice Emitted when assets for a resolved request are claimed.
    /// @param user Address receiving claimed assets.
    /// @param requestId Id of the claimed request.
    /// @param requestType Withdraw lane of the claimed request.
    /// @param assetsClaimed Asset amount transferred to the user.
    event WithdrawRequestClaimed(
        address indexed user,
        uint256 indexed requestId,
        DataTypes.WithdrawRequestType requestType,
        uint256 assetsClaimed
    );

    /// @notice Creates a new withdrawal request in the selected lane.
    /// @param shares Share amount to queue for withdrawal.
    /// @param requestType Withdraw lane for accounting/resolution.
    function requestWithdraw(uint256 shares, DataTypes.WithdrawRequestType requestType) external;

    /// @notice Cancels a pending withdrawal request.
    /// @param id Id of the request to cancel.
    /// @param requestType Withdraw lane where the request exists.
    function cancelWithdrawRequest(uint256 id, DataTypes.WithdrawRequestType requestType) external;

    /// @notice Claims from the caller's currently claimable request.
    /// @param requestType Withdraw lane to claim from.
    function withdraw(DataTypes.WithdrawRequestType requestType) external;

    /// @notice Resolves a batch of queued withdrawal requests.
    /// @param data Resolution payload containing ids and accounting inputs.
    function resolveWithdrawRequests(DataTypes.ResolveWithdrawRequestsData memory data) external;

    /// @notice Returns the vault address linked to this manager.
    function vault() external view returns (address);

    /// @notice Returns the underlying asset paid out on withdrawals.
    function asset() external view returns (address);

    /// @notice Returns the next withdrawal request id for a lane.
    /// @param requestType Withdraw lane queried.
    function nextWithdrawRequestId(DataTypes.WithdrawRequestType requestType) external view returns (uint256);

    /// @notice Returns request data for a specific withdrawal id and lane.
    /// @param id Withdrawal request id.
    /// @param requestType Withdraw lane queried.
    function withdrawRequest(uint256 id, DataTypes.WithdrawRequestType requestType)
        external
        view
        returns (DataTypes.WithdrawRequestData memory);

    /// @notice Returns request data for a batch of withdrawal ids.
    /// @param ids Withdrawal request ids to fetch.
    /// @param requestType Withdraw lane queried.
    function withdrawRequests(uint256[] memory ids, DataTypes.WithdrawRequestType requestType)
        external
        view
        returns (DataTypes.WithdrawRequestData[] memory);

    /// @notice Returns the latest request owned by a user and its id.
    /// @param user Address whose request is queried.
    /// @param requestType Withdraw lane queried.
    function userWithdrawRequest(address user, DataTypes.WithdrawRequestType requestType)
        external
        view
        returns (DataTypes.WithdrawRequestData memory, uint256);

    /// @notice Returns total shares currently pending in a withdraw lane.
    /// @param requestType Withdraw lane queried.
    function totalPendingWithdraws(DataTypes.WithdrawRequestType requestType) external view returns (uint256);

    /// @notice Returns the current resolution cursor for a withdraw lane.
    /// @param requestType Withdraw lane queried.
    function resolutionIdPointer(DataTypes.WithdrawRequestType requestType) external view returns (uint256);

    /// @notice Returns decimal offset used for share/asset conversion.
    function vaultDecimalOffset() external view returns (uint8);
}
