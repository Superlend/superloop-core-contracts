// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {SuperloopStorage} from "../lib/SuperloopStorage.sol";
import {Errors} from "../../common/Errors.sol";

/**
 * @title SuperloopBase
 * @author Superlend
 * @notice Base contract providing configuration and management functionality for Superloop vaults
 * @dev Handles vault settings, module registration, role management, and privileged address control
 */
abstract contract SuperloopBase {
    event SupplyCapUpdated(uint256 oldCap, uint256 newCap);
    event MinimumDepositAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event InstantWithdrawFeeUpdated(uint256 oldFee, uint256 newFee);
    event SuperloopModuleRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event RegisteredModuleUpdated(address indexed module, bool oldStatus, bool newStatus);
    event CallbackHandlerUpdated(bytes32 indexed key, address indexed oldHandler, address indexed newHandler);
    event AccountantModuleUpdated(address indexed oldModule, address indexed newModule);
    event WithdrawManagerModuleUpdated(address indexed oldModule, address indexed newModule);
    event DepositManagerModuleUpdated(address indexed oldModule, address indexed newModule);
    event VaultAdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event PrivilegedAddressUpdated(address indexed privilegedAddress, uint256 oldStatus, uint256 newStatus);
    event CashReserveUpdated(uint256 oldReserve, uint256 newReserve);
    event FallbackHandlerUpdated(bytes32 indexed key, address indexed oldHandler, address indexed newHandler);
    event VaultOperatorUpdated(address indexed oldOperator, address indexed newOperator);

    function setSupplyCap(uint256 supplyCap_) external onlyVaultAdmin {
        uint256 oldCap = SuperloopStorage.getSuperloopStorage().supplyCap;
        SuperloopStorage.setSupplyCap(supplyCap_);
        emit SupplyCapUpdated(oldCap, supplyCap_);
    }

    function setMinimumDepositAmount(uint256 minimumDepositAmount_) external onlyVaultAdmin {
        uint256 oldAmount = SuperloopStorage.getSuperloopStorage().minimumDepositAmount;
        SuperloopStorage.setMinimumDepositAmount(minimumDepositAmount_);
        emit MinimumDepositAmountUpdated(oldAmount, minimumDepositAmount_);
    }

    function setInstantWithdrawFee(uint256 instantWithdrawFee_) external onlyVaultAdmin {
        _setInstantWithdrawFee(instantWithdrawFee_);
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

    function setFallbackHandler(bytes32 key, address handler_) external onlyVaultAdmin {
        address oldHandler = SuperloopStorage.getSuperloopStorage().fallbackHandlers[key];
        SuperloopStorage.setFallbackHandler(key, handler_);
        emit FallbackHandlerUpdated(key, oldHandler, handler_);
    }

    function setAccountantModule(address accountantModule_) external onlyVaultAdmin {
        address oldModule = SuperloopStorage.getSuperloopEssentialRolesStorage().accountant;
        SuperloopStorage.setAccountantModule(accountantModule_);
        emit AccountantModuleUpdated(oldModule, accountantModule_);
    }

    function setWithdrawManagerModule(address withdrawManagerModule_) external onlyVaultAdmin {
        address currentWithdrawManagerModule = SuperloopStorage.getSuperloopEssentialRolesStorage().withdrawManager;

        _setPrivilegedAddress(currentWithdrawManagerModule, false);
        SuperloopStorage.setWithdrawManagerModule(withdrawManagerModule_);
        _setPrivilegedAddress(withdrawManagerModule_, true);
        emit WithdrawManagerModuleUpdated(currentWithdrawManagerModule, withdrawManagerModule_);
    }

    function setDepositManagerModule(address depositManagerModule_) external onlyVaultAdmin {
        address currentDepositManagerModule = SuperloopStorage.getSuperloopEssentialRolesStorage().depositManager;

        _setPrivilegedAddress(currentDepositManagerModule, false);
        SuperloopStorage.setDepositManager(depositManagerModule_);
        _setPrivilegedAddress(depositManagerModule_, true);
        emit DepositManagerModuleUpdated(currentDepositManagerModule, depositManagerModule_);
    }

    function setVaultAdmin(address vaultAdmin_) external onlyVaultAdmin {
        address currentVaultAdmin = SuperloopStorage.getSuperloopEssentialRolesStorage().vaultAdmin;

        _setPrivilegedAddress(currentVaultAdmin, false);
        SuperloopStorage.setVaultAdmin(vaultAdmin_);
        _setPrivilegedAddress(vaultAdmin_, true);
        emit VaultAdminUpdated(currentVaultAdmin, vaultAdmin_);
    }

    function setVaultOperator(address vaultOperator_) external onlyVaultAdmin {
        address currentVaultOperator = SuperloopStorage.getSuperloopEssentialRolesStorage().vaultOperator;

        _setPrivilegedAddress(currentVaultOperator, false);
        SuperloopStorage.setVaultOperator(vaultOperator_);
        _setPrivilegedAddress(vaultOperator_, true);
        emit VaultOperatorUpdated(currentVaultOperator, vaultOperator_);
    }

    function setTreasury(address treasury_) external onlyVaultAdmin {
        address currentTreasury = SuperloopStorage.getSuperloopEssentialRolesStorage().treasury;

        _setPrivilegedAddress(currentTreasury, false);
        SuperloopStorage.setTreasury(treasury_);
        _setPrivilegedAddress(treasury_, true);
        emit TreasuryUpdated(currentTreasury, treasury_);
    }

    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) external onlyVaultAdmin {
        _setPrivilegedAddress(privilegedAddress_, isPrivileged_);
    }

    function supplyCap() external view returns (uint256) {
        return SuperloopStorage.getSuperloopStorage().supplyCap;
    }

    function minimumDepositAmount() external view returns (uint256) {
        return SuperloopStorage.getSuperloopStorage().minimumDepositAmount;
    }

    function instantWithdrawFee() external view returns (uint256) {
        return SuperloopStorage.getSuperloopStorage().instantWithdrawFee;
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

    function fallbackHandler(bytes32 key) external view returns (address) {
        return SuperloopStorage.getSuperloopStorage().fallbackHandlers[key];
    }

    function cashReserve() external view returns (uint256) {
        return SuperloopStorage.getSuperloopStorage().cashReserve;
    }

    function accountant() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().accountant;
    }

    function withdrawManager() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().withdrawManager;
    }

    function vaultAdmin() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().vaultAdmin;
    }

    function treasury() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().treasury;
    }

    function privilegedAddress(address address_) external view returns (bool) {
        uint256 status = SuperloopStorage.getSuperloopEssentialRolesStorage().privilegedAddresses[address_];
        return status > 0;
    }

    function depositManagerModule() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().depositManager;
    }

    function vaultOperator() external view returns (address) {
        return SuperloopStorage.getSuperloopEssentialRolesStorage().vaultOperator;
    }

    function _setInstantWithdrawFee(uint256 instantWithdrawFee_) internal {
        if (instantWithdrawFee_ > SuperloopStorage.MAX_INSTANT_WITHDRAW_FEE) {
            revert(Errors.INVALID_INSTANT_WITHDRAW_FEE);
        }

        uint256 oldFee = SuperloopStorage.getSuperloopStorage().instantWithdrawFee;
        SuperloopStorage.setInstantWithdrawFee(instantWithdrawFee_);
        emit InstantWithdrawFeeUpdated(oldFee, instantWithdrawFee_);
    }

    function _setPrivilegedAddress(address address_, bool isPrivileged_) internal {
        uint256 oldStatus = SuperloopStorage.getSuperloopEssentialRolesStorage().privilegedAddresses[address_];
        uint256 newStatus = isPrivileged_ ? oldStatus + 1 : oldStatus > 0 ? oldStatus - 1 : 0;
        SuperloopStorage.setPrivilegedAddress(address_, newStatus);
        emit PrivilegedAddressUpdated(address_, oldStatus, newStatus);
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
