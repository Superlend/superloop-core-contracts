// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

interface IWithdrawManager {
    event WithdrawRequest(address indexed user, uint256 shares, uint256 id);

    function nextWithdrawRequestId() external view returns (uint256);

    function totalWithdrawableShares() external view returns (uint256);

    function userWithdrawRequestId(
        address user
    ) external view returns (uint256);

    function withdrawRequest(
        uint256 id
    ) external view returns (DataTypes.WithdrawRequestData memory);

    function withdrawWindow() external view returns (uint256, uint256);
}
