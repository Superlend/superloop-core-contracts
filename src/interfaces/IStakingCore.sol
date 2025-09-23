// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStakingCore {
    function stake(string memory communityCode) external payable;
}
