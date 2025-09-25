// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IStakingCore
 * @author Superlend
 * @notice Interface for staking core operations
 * @dev Handles staking operations with community code support
 */
interface IStakingCore {
    /**
     * @notice Stakes ETH with a community code
     * @param communityCode The community code for the stake
     */
    function stake(string memory communityCode) external payable;
}
