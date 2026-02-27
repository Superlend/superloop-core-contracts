// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IStakingManager
 * @author Superlend
 * @notice Interface for staking manager operations
 * @dev Handles staking operations with ETH payments
 */
interface IStakingManager {
    /**
     * @notice Stakes ETH
     */
    function stake() external payable;
}
