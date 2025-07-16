// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ISuperloopModuleRegistry} from "../../interfaces/IModuleRegistry.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";

abstract contract SuperloopModuleRegistryStorage is ISuperloopModuleRegistry {
    string[] private _moduleNames;
    mapping(bytes32 => address) private _moduleRegistry;
    mapping(address => string) private _moduleWhitelist;

    function getModuleByName(string calldata name) public view returns (DataTypes.ModuleData memory) {
        return DataTypes.ModuleData(name, _moduleRegistry[_getModuleIdFromName(name)]);
    }

    function getModuleByAddress(address moduleAddress) public view returns (DataTypes.ModuleData memory) {
        string memory _moduleName = _moduleWhitelist[moduleAddress];

        return DataTypes.ModuleData(_moduleName, _moduleRegistry[_getModuleIdFromName(_moduleName)]);
    }

    function getModules() public view returns (DataTypes.ModuleData[] memory) {
        uint256 modulesCount = _moduleNames.length;
        DataTypes.ModuleData[] memory moduleData = new DataTypes.ModuleData[](modulesCount);

        for (uint256 idx; idx < modulesCount;) {
            string memory _name = _moduleNames[idx];
            moduleData[idx] = DataTypes.ModuleData(_name, _moduleRegistry[_getModuleIdFromName(_name)]);
            unchecked {
                ++idx;
            }
        }

        return moduleData;
    }

    function _setModule(string memory _name, address _module) internal {
        require(bytes(_name).length > 0, Errors.INVALID_MODULE_NAME);
        require(_module != address(0), Errors.INVALID_ADDRESS);

        bytes32 id = _getModuleIdFromName(_name);
        _moduleNames.push(_name);
        _moduleRegistry[id] = _module;

        emit ModuleSet(_name, id, _module);
    }

    function _getModuleIdFromName(string memory _name) internal pure returns (bytes32) {
        return keccak256(abi.encode(_name));
    }
}
