// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {SuperloopStorage} from "../lib/SuperloopStorage.sol";
import {Errors} from "../../common/Errors.sol";

abstract contract SuperloopBase {
    function setSupplyCap(uint256 supplyCap_) external onlyVaultAdmin {
        SuperloopStorage.setSupplyCap(supplyCap_);
    }

    function setSuperloopModuleRegistry(address superloopModuleRegistry_) external onlyVaultAdmin {
        SuperloopStorage.setSuperloopModuleRegistry(superloopModuleRegistry_);
    }

    function setRegisteredModule(address module_, bool registered_) external onlyVaultAdmin {
        SuperloopStorage.setRegisteredModule(module_, registered_);
    }

    function setCallbackHandler(bytes32 key, address handler_) external onlyVaultAdmin {
        SuperloopStorage.setCallbackHandler(key, handler_);
    }

    function setAccountantModule(address accountantModule_) external onlyVaultAdmin {
        SuperloopStorage.setAccountantModule(accountantModule_);
    }

    function setWithdrawManagerModule(address withdrawManagerModule_) external onlyVaultAdmin {
        address currentWithdrawManagerModule =
            SuperloopStorage.getSuperloopEssentialRolesStorage().withdrawManagerModule;

        SuperloopStorage.setPrivilegedAddress(currentWithdrawManagerModule, false);
        SuperloopStorage.setWithdrawManagerModule(withdrawManagerModule_);
        SuperloopStorage.setPrivilegedAddress(withdrawManagerModule_, true);
    }

    function setVaultAdmin(address vaultAdmin_) external onlyVaultAdmin {
        address currentVaultAdmin = SuperloopStorage.getSuperloopEssentialRolesStorage().vaultAdmin;

        SuperloopStorage.setPrivilegedAddress(currentVaultAdmin, false);
        SuperloopStorage.setVaultAdmin(vaultAdmin_);
        SuperloopStorage.setPrivilegedAddress(vaultAdmin_, true);
    }

    function setTreasury(address treasury_) external onlyVaultAdmin {
        address currentTreasury = SuperloopStorage.getSuperloopEssentialRolesStorage().treasury;

        SuperloopStorage.setPrivilegedAddress(currentTreasury, false);
        SuperloopStorage.setTreasury(treasury_);
        SuperloopStorage.setPrivilegedAddress(treasury_, true);
    }

    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) external onlyVaultAdmin {
        SuperloopStorage.setPrivilegedAddress(privilegedAddress_, isPrivileged_);
    }

    function supplyCap() external view returns (uint256) {
        return SuperloopStorage.getSuperloopStorage().supplyCap;
    }

    function superloopModuleRegistry() external view returns (address) {
        return SuperloopStorage.getSuperloopStorage().superloopModuleRegistry;
    }

    function registeredModule(address module_) external view returns (bool) {
        return SuperloopStorage.getSuperloopStorage().registeredModules[module_];
    }

    function callbackHandler(bytes32 key) external view returns (address) {
        return SuperloopStorage.getSuperloopStorage().callbackHandlers[key];
    }

    function accountantModule() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().accountantModule;
    }

    function withdrawManagerModule() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().withdrawManagerModule;
    }

    function vaultAdmin() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().vaultAdmin;
    }

    function treasury() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().treasury;
    }

    function privilegedAddress(address address_) external view returns (bool) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().privilegedAddresses[address_];
    }

    modifier onlyVaultAdmin() {
        _onlyVaultAdmin();
        _;
    }

    function _onlyVaultAdmin() internal view {
        SuperloopStorage.SuperloopEssentialRoles storage $ = SuperloopStorage.getSuperloopEssentialRolesStorage();
        require(msg.sender == $.vaultAdmin, Errors.CALLER_NOT_VAULT_ADMIN);
    }
}
