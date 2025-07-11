// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

interface ISuperloopModuleRegistry {
    event ModuleSet(string name, bytes32 indexed id, address indexed module);

    function getModule(
        string calldata name
    ) external returns (DataTypes.ModuleData memory);

    function getModules() external returns (DataTypes.ModuleData[] memory);

    function setModule(string memory name, address module) external;
}
