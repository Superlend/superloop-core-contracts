// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ICurvePool
 * @author Superlend
 * @notice Mock Curve pool interface for testing purposes
 * @dev Provides interface for Curve pool exchange operations
 */
interface ICurvePool {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
}
