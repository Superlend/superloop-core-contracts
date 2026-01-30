// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UniversalAccountantStorage} from "../../lib/UniversalAccountantStorage.sol";
import {IAccountantModule} from "../../../interfaces/IAccountantModule.sol";

/**
 * @title UniversalAccountantBase
 * @author Superlend
 * @notice Base contract providing owner-controlled configuration for UniversalAccountant
 * @dev Handles owner-only functions for setting registered accountants, performance fee, and vault address
 */
abstract contract UniversalAccountantBase is OwnableUpgradeable, IAccountantModule {
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);
    event VaultUpdated(address indexed oldVault, address indexed newVault);
    event RegisteredAccountantsUpdated(address[] oldAccountants, address[] newAccountants);

    function __UniversalAccountantBase_init(address owner) internal onlyInitializing {
        __Ownable_init(owner);
    }

    /**
     * @notice Sets the list of registered accountant plugins to aggregate assets from
     * @param registeredAccountants_ Array of accountant plugin addresses
     */
    function setRegisteredAccountants(address[] memory registeredAccountants_) external onlyOwner {
        address[] memory oldAccountants =
        UniversalAccountantStorage.getUniversalAccountantStorage().registeredAccountants;
        UniversalAccountantStorage.setRegisteredAccountants(registeredAccountants_);
        emit RegisteredAccountantsUpdated(oldAccountants, registeredAccountants_);
    }

    /**
     * @notice Sets the performance fee rate in basis points
     * @param performanceFee_ Performance fee in basis points (BPS)
     */
    function setPerformanceFee(uint16 performanceFee_) external onlyOwner {
        uint16 oldFee = UniversalAccountantStorage.getUniversalAccountantStorage().performanceFee;
        UniversalAccountantStorage.setPerformanceFee(performanceFee_);
        emit PerformanceFeeUpdated(oldFee, performanceFee_);
    }

    /**
     * @notice Sets the vault address that this accountant is associated with
     * @param vault_ Address of the Superloop vault
     */
    function setVault(address vault_) external onlyOwner {
        address oldVault = UniversalAccountantStorage.getUniversalAccountantStorage().vault;
        UniversalAccountantStorage.setVault(vault_);
        emit VaultUpdated(oldVault, vault_);
    }

    function registeredAccountants() external view returns (address[] memory) {
        return UniversalAccountantStorage.getUniversalAccountantStorage().registeredAccountants;
    }

    function performanceFee() external view returns (uint16) {
        return UniversalAccountantStorage.getUniversalAccountantStorage().performanceFee;
    }

    function vault() external view returns (address) {
        return UniversalAccountantStorage.getUniversalAccountantStorage().vault;
    }

    function lastRealizedFeeExchangeRate() external view returns (uint256) {
        return UniversalAccountantStorage.getUniversalAccountantStorage().lastRealizedFeeExchangeRate;
    }
}
