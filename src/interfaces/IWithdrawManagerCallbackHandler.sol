// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IWithdrawManagerCallbackHandler {
    function executeWithdraw(uint256, bytes calldata params) external returns (bool);
}
