// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IOverseerV1
 * @author Superlend
 * @notice Interface for Overseer V1 operations
 * @dev Handles minting operations with ETH payments
 */
interface IOverseerV1 {
    /**
     * @notice Mints tokens to the specified address
     * @param to The address to mint tokens to
     * @return The amount of tokens minted
     */
    function mint(address to) external payable returns (uint256);
}
