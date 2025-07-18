// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

interface IWithdrawManager {
    // TODO: add events

    event WithdrawRequest(address indexed user, uint256 shares, uint256 amount, uint256 id);

    function requestWithdraw(uint256 shares) external;

    function resolveWithdrawRequests(uint256 resolvedIdLimit) external;

    function withdraw() external;

    function cancelWithdrawRequest(uint256 id) external;

    function getWithdrawRequestState(uint256 id) external view returns (DataTypes.WithdrawRequestState);

    function vault() external view returns (address);

    function asset() external view returns (address);

    function nextWithdrawRequestId() external view returns (uint256);

    function resolvedWithdrawRequestId() external view returns (uint256);

    function withdrawRequest(uint256 id) external view returns (DataTypes.WithdrawRequestData memory);

    function withdrawRequests(uint256[] memory ids) external view returns (DataTypes.WithdrawRequestData[] memory);

    function userWithdrawRequestId(address user) external view returns (uint256);
}
