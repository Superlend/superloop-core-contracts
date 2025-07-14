// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {WithdrawManagerStorage} from "./WithdrawManagerStorage.sol";
// import {IERC20} from "";

contract WithdrawManager is WithdrawManagerStorage {
    constructor() {}

    function requestWithdraw(uint256 shares) external {
        // make sure the msg.sender has enough shares
        // make sure the user does not have any withdraw request active
        // TODO: handle fee ??
        // register this withdraw request
    }
}
