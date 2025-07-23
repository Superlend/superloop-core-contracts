// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {DataTypes} from "../common/DataTypes.sol";

interface ISuperloop is IERC4626 {
    function operate(DataTypes.ModuleExecutionData[] memory moduleExecutionData) external;

    function operateSelf(DataTypes.ModuleExecutionData[] memory moduleExecutionData) external;

    function skim(address asset_) external;

    function setSupplyCap(uint256 supplyCap_) external;

    function setSuperloopModuleRegistry(address superloopModuleRegistry_) external;

    function setRegisteredModule(address module_, bool registered_) external;

    function setCallbackHandler(bytes32 key, address handler_) external;

    function setAccountantModule(address accountantModule_) external;

    function setWithdrawManagerModule(address withdrawManagerModule_) external;

    function setVaultAdmin(address vaultAdmin_) external;
    function setTreasury(address treasury_) external;

    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) external;

    function supplyCap() external view returns (uint256);

    function superloopModuleRegistry() external view returns (address);

    function registeredModule(address module_) external view returns (bool);

    function callbackHandler(bytes32 key) external view returns (address);

    function accountantModule() external view returns (address);

    function withdrawManagerModule() external view returns (address);

    function vaultAdmin() external view returns (address);

    function treasury() external view returns (address);

    function privilegedAddress(address address_) external view returns (bool);
}
