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
     * @notice Maximum BPS value
     */
    uint256 public constant MAX_BPS_VALUE = 10000; // 100%

    /**
     * @notice Maximum instant withdraw fee
     */
    uint256 public constant MAX_INSTANT_WITHDRAW_FEE = 100; // 1%

    /**
     * @notice Structure for storing Superloop vault state
     * @param supplyCap The maximum supply cap for the vault
     * @param minimumDepositAmount The minimum deposit amount for the vault
     * @param instantWithdrawFee The instant withdraw fee for the vault
     * @param superloopModuleRegistry The address of the module registry
     * @param registeredModules Mapping from module address to registration status
     * @param callbackHandlers Mapping from callback key to handler address
     * @param cashReserve The amount of cash reserve for the vault. Represented in BPS
     * @param fallbackHandlers Mapping from fallback key to handler address
     */
    struct SuperloopState {
        uint256 supplyCap;
        uint256 minimumDepositAmount;
        uint256 instantWithdrawFee;
        address superloopModuleRegistry;
        uint256 cashReserve;
        mapping(address => bool) registeredModules;
        mapping(bytes32 => address) callbackHandlers;
        mapping(bytes32 => address) fallbackHandlers;
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
     * @notice Sets the minimum deposit amount for the vault
     * @param minimumDepositAmount_ The new minimum deposit amount value
     */
    function setMinimumDepositAmount(uint256 minimumDepositAmount_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.minimumDepositAmount = minimumDepositAmount_;
    }

    /**
     * @notice Sets the instant withdraw fee for the vault
     * @param instantWithdrawFee_ The new instant withdraw fee value
     */
    function setInstantWithdrawFee(uint256 instantWithdrawFee_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.instantWithdrawFee = instantWithdrawFee_;
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
     * @notice Sets the cash reserve for the vault
     * @param cashReserve_ The new cash reserve value
     */
    function setCashReserve(uint256 cashReserve_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.cashReserve = cashReserve_;
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
     * @notice Sets a fallback handler for a specific key
     * @param key The key identifier for the fallback handler
     * @param handler_ The address of the fallback handler
     */
    function setFallbackHandler(bytes32 key, address handler_) internal {
        SuperloopState storage $ = getSuperloopStorage();
        $.fallbackHandlers[key] = handler_;
    }

    /**
     * @notice Structure for storing Superloop essential roles
     * @param accountant The address of the accountant module
     * @param withdrawManager The address of the withdraw manager module
     * @param vaultAdmin The address of the vault admin
     * @param treasury The address of the treasury
     * @param privilegedAddresses Mapping from address to privileged status
     */
    struct SuperloopEssentialRoles {
        address accountant;
        address withdrawManager;
        address depositManager;
        address vaultOperator;
        address vaultAdmin;
        address treasury;
        mapping(address => uint256) privilegedAddresses;
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
        $.accountant = accountantModule_;
    }

    /**
     * @notice Sets the withdraw manager module address
     * @param withdrawManagerModule_ The address of the withdraw manager module
     */
    function setWithdrawManagerModule(address withdrawManagerModule_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.withdrawManager = withdrawManagerModule_;
    }

    /**
     * @notice Sets the deposit manager module address
     * @param depositManagerModule_ The address of the deposit manager module
     */
    function setDepositManager(address depositManagerModule_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.depositManager = depositManagerModule_;
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
     * @notice Sets the vault operator address
     * @param vaultOperator_ The address of the vault operator
     */
    function setVaultOperator(address vaultOperator_) internal {
        SuperloopEssentialRoles storage $ = getSuperloopEssentialRolesStorage();
        $.vaultOperator = vaultOperator_;
    }

    /**
     * @notice Sets privileged status for an address
     * @param privilegedAddress_ The address to set privileged status for
     * @param isPrivileged_ True to grant privileges, false to revoke
     */
    function setPrivilegedAddress(address privilegedAddress_, uint256 isPrivileged_) internal {
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
