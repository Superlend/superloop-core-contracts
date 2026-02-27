// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title ISuperloopModuleRegistry
 * @author Superlend
 * @notice Interface for Superloop module registry operations
 * @dev Manages module registration, retrieval, and whitelisting functionality
 */
interface ISuperloopModuleRegistry {
    /**
     * @notice Emitted when a module is set in the registry
     * @param name The name of the module
     * @param id The unique identifier for the module
     * @param module The address of the module
     */
    event ModuleSet(string name, bytes32 indexed id, address indexed module);

    /**
     * @notice Retrieves module data by name
     * @param name The name of the module to retrieve
     * @return The module data structure
     */
    function getModuleByName(string calldata name) external returns (DataTypes.ModuleData memory);

    /**
     * @notice Retrieves module data by address
     * @param moduleAddress The address of the module to retrieve
     * @return The module data structure
     */
    function getModuleByAddress(address moduleAddress) external returns (DataTypes.ModuleData memory);

    /**
     * @notice Retrieves all registered modules
     * @return Array of all module data structures
     */
    function getModules() external returns (DataTypes.ModuleData[] memory);

    /**
     * @notice Checks if a module address is whitelisted
     * @param moduleAddress The address of the module to check
     * @return True if the module is whitelisted, false otherwise
     */
    function isModuleWhitelisted(address moduleAddress) external view returns (bool);

    /**
     * @notice Sets a module in the registry
     * @param name The name of the module
     * @param module The address of the module
     */
    function setModule(string memory name, address module) external;
}
