// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IOverseerV1 {
    function mint(address to) external payable returns (uint256);
}
