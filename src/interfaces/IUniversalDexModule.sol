// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title IUniversalDexModule
 * @author Superlend
 * @notice Interface for universal DEX module operations
 * @dev Handles token swaps and exchange operations across multiple DEX protocols
 */
interface IUniversalDexModule {
    /**
     * @notice Executes a token swap operation
     * @param params The parameters for the swap operation
     * @return The amount of output tokens received
     */
    function execute(DataTypes.ExecuteSwapParams memory params) external returns (uint256);

    /**
     * @notice Executes a token swap and transfers the result to a specified address
     * @param params The parameters for the swap operation
     * @param to The address to receive the swapped tokens
     * @return The amount of output tokens received
     */
    function executeAndExit(DataTypes.ExecuteSwapParams memory params, address to) external returns (uint256);
}
