// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title IAaveV3ActionModule
 * @author Superlend
 * @notice Interface for executing Aave V3 action modules
 * @dev Inherits from DataTypes
 */
interface IAaveV3ActionModule {
    /**
     * @notice Executes an Aave V3 action module
     * @param params The parameters for the action module
     */
    function execute(DataTypes.AaveV3ActionParams memory params) external;
}
