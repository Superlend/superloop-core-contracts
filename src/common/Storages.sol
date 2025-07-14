// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "./DataTypes.sol";

library Storages {
    struct WithdrawManagerState {
        address vault;
        uint256 withdrawWindowStartId;
        uint256 withdrawWindowEndId;
        uint256 nextWithdrawRequestId;
        uint256 totalWithdrawableShares;
        mapping(uint256 => DataTypes.WithdrawRequestData) withdrawRequest;
        mapping(address => uint256) userWithdrawRequestId;
    }
}
