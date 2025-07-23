// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockAsset
 * @author Superlend
 * @notice Mock ERC20 token for testing purposes
 * @dev Provides basic ERC20 functionality with minting and burning capabilities
 */
contract MockAsset is ERC20 {
    /**
     * @notice Constructor to initialize the mock asset
     * @dev Mints initial supply to the deployer
     */
    constructor() ERC20("Mock Asset", "MOCK") {
        _mint(msg.sender, 1000000000 * 10 ** 18);
    }

    /**
     * @notice Mints new tokens to the caller
     * @param amount The amount of tokens to mint
     */
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from the caller
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
