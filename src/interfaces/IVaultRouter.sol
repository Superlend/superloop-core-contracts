// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title IVaultRouter
 * @author Superlend
 * @notice Interface for vault routing operations including deposits and whitelist management
 * @dev Handles token deposits with optional swaps and vault/token whitelisting
 */
interface VaultRouter {
    /**
     * @notice Deposits tokens into a vault with optional swap functionality
     * @param vault The address of the target vault
     * @param tokenIn The address of the input token
     * @param amountIn The amount of input tokens to deposit
     * @param swapParams Parameters for executing a swap if needed
     * @return The number of shares received from the deposit
     */
    function depositWithToken(
        address vault,
        address tokenIn,
        uint256 amountIn,
        DataTypes.ExecuteSwapParams memory swapParams
    ) external returns (uint256);

    /**
     * @notice Adds or removes a vault from the whitelist
     * @param vault The address of the vault to whitelist/unwhitelist
     * @param isWhitelisted True to whitelist, false to remove from whitelist
     */
    function whitelistVault(address vault, bool isWhitelisted) external;

    /**
     * @notice Adds or removes a token from the whitelist
     * @param token The address of the token to whitelist/unwhitelist
     * @param isWhitelisted True to whitelist, false to remove from whitelist
     */
    function whitelistToken(address token, bool isWhitelisted) external;

    /**
     * @notice Sets the universal DEX module address
     * @param _universalDexModule The address of the universal DEX module
     */
    function setUniversalDexModule(address _universalDexModule) external;
}
