// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title SuperloopStorage
 * @author Superlend
 * @notice Library for managing Superloop vault storage and state
 * @dev Provides storage management functions for Superloop state, roles, and execution context
 */
library SuperloopStorage {
    /**
     * @notice Decimal offset constant for calculations
     */
    uint8 public constant DECIMALS_OFFSET = 2;

    /**
     * @notice Structure for storing Superloop vault state
     * @param supplyCap The maximum supply cap for the vault
     * @param superloopModuleRegistry The address of the module registry
     * @param registeredModules Mapping from module address to registration status
     * @param callbackHandlers Mapping from callback key to handler address
     */
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

    /**
     * @notice Gets the Superloop state storage slot
     * @return $ The Superloop state storage reference
     */
    function getSuperloopStorage() internal pure returns (SuperloopState storage $) {
        assembly {
            $.slot := SuperloopStateStorageLocation
        }
    }

    // setter functions
    /**
     * @notice Sets the supply cap for the vault
     * @param supplyCap_ The new supply cap value
     */
    function setSupplyCap(uint256 supplyCap_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.supplyCap = supplyCap_;
    }

    /**
     * @notice Sets the registration status of a module
     * @param module_ The address of the module
     * @param registered_ True to register, false to unregister
     */
    function setRegisteredModule(address module_, bool registered_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.registeredModules[module_] = registered_;
    }

    /**
     * @notice Sets the Superloop module registry address
     * @param superloopModuleRegistry_ The address of the module registry
     */
    function setSuperloopModuleRegistry(address superloopModuleRegistry_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.superloopModuleRegistry = superloopModuleRegistry_;
    }

    /**
     * @notice Sets a callback handler for a specific key
     * @param key The key identifier for the callback handler
     * @param handler_ The address of the callback handler
     */
    function setCallbackHandler(bytes32 key, address handler_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.callbackHandlers[key] = handler_;
    }

    /**
     * @notice Structure for storing Superloop essential roles
     * @param accountantModule The address of the accountant module
     * @param withdrawManagerModule The address of the withdraw manager module
     * @param vaultAdmin The address of the vault admin
     * @param treasury The address of the treasury
     * @param privilegedAddresses Mapping from address to privileged status
     */
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

    /**
     * @notice Gets the Superloop essential roles storage slot
     * @return $ The Superloop essential roles storage reference
     */
    function getSuperloopEssentialRolesStorage() internal pure returns (SuperloopEssentialRoles storage $) {
        assembly {
            $.slot := SuperloopEssentialRolesStorageLocation
        }
    }

    /**
     * @notice Sets the accountant module address
     * @param accountantModule_ The address of the accountant module
     */
    function setAccountantModule(address accountantModule_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.accountantModule = accountantModule_;
    }

    /**
     * @notice Sets the withdraw manager module address
     * @param withdrawManagerModule_ The address of the withdraw manager module
     */
    function setWithdrawManagerModule(address withdrawManagerModule_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.withdrawManagerModule = withdrawManagerModule_;
    }

    /**
     * @notice Sets the vault admin address
     * @param vaultAdmin_ The address of the vault admin
     */
    function setVaultAdmin(address vaultAdmin_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.vaultAdmin = vaultAdmin_;
    }

    /**
     * @notice Sets the treasury address
     * @param treasury_ The address of the treasury
     */
    function setTreasury(address treasury_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.treasury = treasury_;
    }

    /**
     * @notice Sets privileged status for an address
     * @param privilegedAddress_ The address to set privileged status for
     * @param isPrivileged_ True to grant privileges, false to revoke
     */
    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.privilegedAddresses[privilegedAddress_] = isPrivileged_;
    }

    /**
     * @notice Structure for storing execution context state
     * @param value Boolean indicating if currently in execution context
     */
    struct SuperloopExecutionContext {
        bool value;
    }

    /**
     * @dev Storage location constant for the superloop essential roles storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.Superloop.executionContext")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopExecutionContextStorageLocation =
        0x09ba4f032e25ab064c0a0b578597c657b2f04d2ad4f0677d98d0b504efa6c800;

    /**
     * @notice Gets the Superloop execution context storage slot
     * @return $ The Superloop execution context storage reference
     */
    function getSuperloopExecutionContextStorage() internal pure returns (SuperloopExecutionContext storage $) {
        assembly {
            $.slot := SuperloopExecutionContextStorageLocation
        }
    }

    /**
     * @notice Begins an execution context
     */
    function beginExecutionContext() internal {
        SuperloopExecutionContext storage $ = getSuperloopExecutionContextStorage();
        $.value = true;
    }

    /**
     * @notice Ends an execution context
     */
    function endExecutionContext() internal {
        SuperloopExecutionContext storage $ = getSuperloopExecutionContextStorage();
        $.value = false;
    }

    /**
     * @notice Checks if currently in an execution context
     * @return True if in execution context, false otherwise
     */
    function isInExecutionContext() internal view returns (bool) {
        SuperloopExecutionContext storage $ = getSuperloopExecutionContextStorage();
        return $.value;
    }
}
