// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDepositManagerCallbackHandler {
    function executeDeposit(uint256, bytes calldata params) external returns (bool);
}
