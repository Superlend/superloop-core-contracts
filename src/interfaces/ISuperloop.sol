// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title ISuperloop
 * @author Superlend
 * @notice Interface for Superloop vault operations extending ERC4626 functionality
 * @dev Provides module execution, asset management, and configuration capabilities
 */
interface ISuperloop is IERC4626 {
    /**
     * @notice Executes multiple module operations
     * @param moduleExecutionData Array of module execution data
     */
    function operate(DataTypes.ModuleExecutionData[] memory moduleExecutionData) external;

    /**
     * @notice Executes module operations on behalf of the vault itself
     * @param moduleExecutionData Array of module execution data
     */
    function operateSelf(DataTypes.ModuleExecutionData[] memory moduleExecutionData) external;

    /**
     * @notice Skims excess tokens from the vault
     * @param asset_ The address of the asset to skim
     */
    function skim(address asset_) external;

    /**
     * @notice Gets the pause state of the vault
     * @return The pause state of the vault
     */
    function paused() external view returns (bool);

    /**
     * @notice Realizes the performance fee
     */
    function realizePerformanceFee() external;

    /**
     * @notice Mints shares for an address
     * @param to The address to mint shares for
     * @param amount The amount of shares to mint
     */
    function mintShares(address to, uint256 amount) external;

    /**
     * @notice Burns shares and claims assets for an address
     * @param shares The amount of shares to burn
     * @param assets The amount of assets to claim
     */
    function burnSharesAndClaimAssets(uint256 shares, uint256 assets) external;

    /**
     * @notice Sets the supply cap for the vault
     * @param supplyCap_ The new supply cap value
     */
    function setSupplyCap(uint256 supplyCap_) external;

    /**
     * @notice Sets the Superloop module registry address
     * @param superloopModuleRegistry_ The address of the module registry
     */
    function setSuperloopModuleRegistry(address superloopModuleRegistry_) external;

    /**
     * @notice Registers or unregisters a module
     * @param module_ The address of the module
     * @param registered_ True to register, false to unregister
     */
    function setRegisteredModule(address module_, bool registered_) external;

    /**
     * @notice Sets a callback handler for a specific key
     * @param key The key identifier for the callback handler
     * @param handler_ The address of the callback handler
     */
    function setCallbackHandler(bytes32 key, address handler_) external;

    /**
     * @notice Sets the accountant module address
     * @param accountantModule_ The address of the accountant module
     */
    function setAccountantModule(address accountantModule_) external;

    /**
     * @notice Sets the withdraw manager module address
     * @param withdrawManagerModule_ The address of the withdraw manager module
     */
    function setWithdrawManagerModule(address withdrawManagerModule_) external;

    /**
     * @notice Sets the vault admin address
     * @param vaultAdmin_ The address of the vault admin
     */
    function setVaultAdmin(address vaultAdmin_) external;

    /**
     * @notice Sets the treasury address
     * @param treasury_ The address of the treasury
     */
    function setTreasury(address treasury_) external;

    /**
     * @notice Sets privileged status for an address
     * @param privilegedAddress_ The address to set privileged status for
     * @param isPrivileged_ True to grant privileges, false to revoke
     */
    function setPrivilegedAddress(address privilegedAddress_, bool isPrivileged_) external;

    /**
     * @notice Gets the supply cap for the vault
     * @return The current supply cap value
     */
    function supplyCap() external view returns (uint256);

    /**
     * @notice Gets the Superloop module registry address
     * @return The address of the module registry
     */
    function superloopModuleRegistry() external view returns (address);

    /**
     * @notice Checks if a module is registered
     * @param module_ The address of the module to check
     * @return True if the module is registered, false otherwise
     */
    function registeredModule(address module_) external view returns (bool);

    /**
     * @notice Gets the callback handler for a specific key
     * @param key The key identifier for the callback handler
     * @return The address of the callback handler
     */
    function callbackHandler(bytes32 key) external view returns (address);

    /**
     * @notice Gets the accountant module address
     * @return The address of the accountant module
     */
    function accountant() external view returns (address);

    /**
     * @notice Gets the withdraw manager module address
     * @return The address of the withdraw manager module
     */
    function withdrawManager() external view returns (address);

    /**
     * @notice Gets the vault admin address
     * @return The address of the vault admin
     */
    function vaultAdmin() external view returns (address);

    /**
     * @notice Gets the treasury address
     * @return The address of the treasury
     */
    function treasury() external view returns (address);

    /**
     * @notice Checks if an address has privileged status
     * @param address_ The address to check
     * @return True if the address has privileges, false otherwise
     */
    function privilegedAddress(address address_) external view returns (bool);
}
