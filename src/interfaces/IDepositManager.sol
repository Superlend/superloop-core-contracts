// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDepositManager {
    function requestDeposit(uint256 amount, address onBehalfOf) external;
}
