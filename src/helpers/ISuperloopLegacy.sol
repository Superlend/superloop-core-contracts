// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ISuperloopLegacy
 * @author Superlend
 * @notice Interface for legacy Superloop vault operations
 * @dev Used for migration purposes to access legacy vault functionality
 */
interface ISuperloopLegacy {
    /**
     * @notice Gets the withdraw manager module address
     * @return The address of the withdraw manager module
     */
    function withdrawManagerModule() external view returns (address);
}
