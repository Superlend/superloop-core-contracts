// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "./DataTypes.sol";

library Storages {
    struct WithdrawManagerState {
        address vault;
        address asset;
        uint256 nextWithdrawRequestId;
        uint256 resolvedWithdrawRequestId;
        mapping(uint256 => DataTypes.WithdrawRequestData) withdrawRequest;
        mapping(address => uint256) userWithdrawRequestId;
    }
}
