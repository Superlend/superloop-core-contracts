// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {SuperloopModuleRegistryStorage} from "./ModuleRegistryStorage.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract SuperloopModuleRegistry is SuperloopModuleRegistryStorage, Ownable {
    constructor() Ownable(msg.sender) {}

    function setModule(string memory name, address module) external onlyOwner {
        _setModule(name, module);
    }
}
