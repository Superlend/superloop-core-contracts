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
        SuperloopStorage.setWithdrawManagerModule(withdrawManagerModule_);
    }

    function setVaultAdmin(address vaultAdmin_) external onlyVaultAdmin {
        SuperloopStorage.setVaultAdmin(vaultAdmin_);
    }

    function setTreasury(address treasury_) external onlyVaultAdmin {
        SuperloopStorage.setTreasury(treasury_);
    }

    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) external onlyVaultAdmin {
        SuperloopStorage.setPrivilegedAddress(privilegedAddress_, isPrivileged_);
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
