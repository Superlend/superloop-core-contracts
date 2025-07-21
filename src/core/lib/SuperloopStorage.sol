// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library SuperloopStorage {
    uint8 public constant DECIMALS_OFFSET = 2;

    struct SuperloopState {
        uint256 supplyCap;
        address superloopModuleRegistry;
        mapping(address => bool) registeredModules;
        mapping(bytes32 => address) callbackHandlers;
    }

    /**
     * @dev Storage location constant for the superloop storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.Superloop.state")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopStateStorageLocation =
        0xa35af3fd1440912a5a47a30e9b58a4830f4700f48114569c6bb05e8eec37b600;

    function getSuperloopStorage() internal pure returns (SuperloopState storage $) {
        assembly {
            $.slot := SuperloopStateStorageLocation
        }
    }

    // setter functions
    function setSupplyCap(uint256 supplyCap_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.supplyCap = supplyCap_;
    }

    function setRegisteredModule(address module_, bool registered_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.registeredModules[module_] = registered_;
    }

    function setSuperloopModuleRegistry(address superloopModuleRegistry_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.superloopModuleRegistry = superloopModuleRegistry_;
    }

    function setCallbackHandler(bytes32 key, address handler_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.callbackHandlers[key] = handler_;
    }

    struct SuperloopEssentialRoles {
        address accountantModule;
        address withdrawManagerModule;
        address vaultAdmin;
        address treasury;
        mapping(address => bool) privilegedAddresses;
    }

    /**
     * @dev Storage location constant for the superloop essential roles storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.Superloop.essentialRoles")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopEssentialRolesStorageLocation =
        0xa51d4770eb956a5b972557fe35f195397c0ff8923964914a00aee9bbbf6e6700;

    function getSuperloopEssentialRolesStorage() internal pure returns (SuperloopEssentialRoles storage $) {
        assembly {
            $.slot := SuperloopEssentialRolesStorageLocation
        }
    }

    function setAccountantModule(address accountantModule_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.accountantModule = accountantModule_;
    }

    function setWithdrawManagerModule(address withdrawManagerModule_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.withdrawManagerModule = withdrawManagerModule_;
    }

    function setVaultAdmin(address vaultAdmin_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.vaultAdmin = vaultAdmin_;
    }

    function setTreasury(address treasury_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.treasury = treasury_;
    }

    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.privilegedAddresses[privilegedAddress_] = isPrivileged_;
    }

    struct SuperloopExecutionContext {
        bool value;
    }

    /**
     * @dev Storage location constant for the superloop essential roles storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.Superloop.executionContext")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopExecutionContextStorageLocation =
        0x09ba4f032e25ab064c0a0b578597c657b2f04d2ad4f0677d98d0b504efa6c800;

    function getSuperloopExecutionContextStorage() internal pure returns (SuperloopExecutionContext storage $) {
        assembly {
            $.slot := SuperloopExecutionContextStorageLocation
        }
    }

    function beginExecutionContext() internal {
        SuperloopExecutionContext storage $ = getSuperloopExecutionContextStorage();
        $.value = true;
    }

    function endExecutionContext() internal {
        SuperloopExecutionContext storage $ = getSuperloopExecutionContextStorage();
        $.value = false;
    }

    function isInExecutionContext() internal view returns (bool) {
        SuperloopExecutionContext storage $ = getSuperloopExecutionContextStorage();
        return $.value;
    }
}
