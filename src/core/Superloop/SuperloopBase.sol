// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {SuperloopStorage} from "../lib/SuperloopStorage.sol";
import {Errors} from "../../common/Errors.sol";

abstract contract SuperloopBase {
    event SupplyCapUpdated(uint256 oldCap, uint256 newCap);
    event SuperloopModuleRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event RegisteredModuleUpdated(address indexed module, bool oldStatus, bool newStatus);
    event CallbackHandlerUpdated(bytes32 indexed key, address indexed oldHandler, address indexed newHandler);
    event AccountantModuleUpdated(address indexed oldModule, address indexed newModule);
    event WithdrawManagerModuleUpdated(address indexed oldModule, address indexed newModule);
    event DepositManagerModuleUpdated(address indexed oldModule, address indexed newModule);
    event VaultAdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event PrivilegedAddressUpdated(address indexed privilegedAddress, bool oldStatus, bool newStatus);
    event CashReserveUpdated(uint256 oldReserve, uint256 newReserve);

    function setSupplyCap(uint256 supplyCap_) external onlyVaultAdmin {
        uint256 oldCap = SuperloopStorage.getSuperloopStorage().supplyCap;
        SuperloopStorage.setSupplyCap(supplyCap_);
        emit SupplyCapUpdated(oldCap, supplyCap_);
    }

    function setSuperloopModuleRegistry(address superloopModuleRegistry_) external onlyVaultAdmin {
        address oldRegistry = SuperloopStorage.getSuperloopStorage().superloopModuleRegistry;
        SuperloopStorage.setSuperloopModuleRegistry(superloopModuleRegistry_);
        emit SuperloopModuleRegistryUpdated(oldRegistry, superloopModuleRegistry_);
    }

    function setRegisteredModule(address module_, bool registered_) external onlyVaultAdmin {
        bool oldStatus = SuperloopStorage.getSuperloopStorage().registeredModules[module_];
        SuperloopStorage.setRegisteredModule(module_, registered_);
        emit RegisteredModuleUpdated(module_, oldStatus, registered_);
    }

    function setCashReserve(uint256 cashReserve_) external onlyVaultAdmin {
        if (cashReserve_ > SuperloopStorage.MAX_BPS_VALUE) {
            revert(Errors.INVALID_CASH_RESERVE);
        }

        uint256 oldReserve = SuperloopStorage.getSuperloopStorage().cashReserve;
        SuperloopStorage.setCashReserve(cashReserve_);
        emit CashReserveUpdated(oldReserve, cashReserve_);
    }

    function setCallbackHandler(bytes32 key, address handler_) external onlyVaultAdmin {
        address oldHandler = SuperloopStorage.getSuperloopStorage().callbackHandlers[key];
        SuperloopStorage.setCallbackHandler(key, handler_);
        emit CallbackHandlerUpdated(key, oldHandler, handler_);
    }

    function setAccountantModule(address accountantModule_) external onlyVaultAdmin {
        address oldModule = SuperloopStorage.getSuperloopEssentialRolesStorage().accountantModule;
        SuperloopStorage.setAccountantModule(accountantModule_);
        emit AccountantModuleUpdated(oldModule, accountantModule_);
    }

    function setWithdrawManagerModule(address withdrawManagerModule_) external onlyVaultAdmin {
        address currentWithdrawManagerModule =
            SuperloopStorage.getSuperloopEssentialRolesStorage().withdrawManagerModule;

        SuperloopStorage.setPrivilegedAddress(currentWithdrawManagerModule, false);
        SuperloopStorage.setWithdrawManagerModule(withdrawManagerModule_);
        SuperloopStorage.setPrivilegedAddress(withdrawManagerModule_, true);
        emit WithdrawManagerModuleUpdated(currentWithdrawManagerModule, withdrawManagerModule_);
    }

    function setDepositManagerModule(address depositManagerModule_) external onlyVaultAdmin {
        address currentDepositManagerModule = SuperloopStorage.getSuperloopEssentialRolesStorage().depositManager;
        SuperloopStorage.setDepositManager(depositManagerModule_);
        emit DepositManagerModuleUpdated(currentDepositManagerModule, depositManagerModule_);
    }

    function setVaultAdmin(address vaultAdmin_) external onlyVaultAdmin {
        address currentVaultAdmin = SuperloopStorage.getSuperloopEssentialRolesStorage().vaultAdmin;

        SuperloopStorage.setPrivilegedAddress(currentVaultAdmin, false);
        SuperloopStorage.setVaultAdmin(vaultAdmin_);
        SuperloopStorage.setPrivilegedAddress(vaultAdmin_, true);
        emit VaultAdminUpdated(currentVaultAdmin, vaultAdmin_);
    }

    function setTreasury(address treasury_) external onlyVaultAdmin {
        address currentTreasury = SuperloopStorage.getSuperloopEssentialRolesStorage().treasury;

        SuperloopStorage.setPrivilegedAddress(currentTreasury, false);
        SuperloopStorage.setTreasury(treasury_);
        SuperloopStorage.setPrivilegedAddress(treasury_, true);
        emit TreasuryUpdated(currentTreasury, treasury_);
    }

    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) external onlyVaultAdmin {
        bool oldStatus = SuperloopStorage.getSuperloopEssentialRolesStorage().privilegedAddresses[privilegedAddress_];
        SuperloopStorage.setPrivilegedAddress(privilegedAddress_, isPrivileged_);
        emit PrivilegedAddressUpdated(privilegedAddress_, oldStatus, isPrivileged_);
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

    function cashReserve() external view returns (uint256) {
        return SuperloopStorage.getSuperloopStorage().cashReserve;
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

    function depositManagerModule() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().depositManager;
    }

    function vaultOperator() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().vaultOperator;
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
