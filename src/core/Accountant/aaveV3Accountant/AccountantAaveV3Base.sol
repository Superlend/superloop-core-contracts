// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {AccountantAaveV3Storage} from "../../lib/AccountantAaveV3Storage.sol";
import {IAccountantAaveV3Module} from "../../../interfaces/IAccountantAaveV3Module.sol";

/**
 * @title AccountantAaveV3Base
 * @author Superlend
 * @notice Base contract providing owner-controlled configuration for AccountantAaveV3
 * @dev Handles owner-only functions for setting Aave V3 pool addresses provider, lend/borrow assets, performance fee, and vault address
 */
abstract contract AccountantAaveV3Base is OwnableUpgradeable, IAccountantAaveV3Module {
    event PoolAddressesProviderUpdated(address indexed oldProvider, address indexed newProvider);
    event LendAssetsUpdated(address[] oldAssets, address[] newAssets);
    event BorrowAssetsUpdated(address[] oldAssets, address[] newAssets);
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);
    event VaultUpdated(address indexed oldVault, address indexed newVault);

    function __AccountantAaveV3Base_init(address owner) internal onlyInitializing {
        __Ownable_init(owner);
    }

    /**
     * @notice Sets the Aave V3 pool addresses provider
     * @param poolAddressesProvider_ Address of the Aave V3 pool addresses provider
     */
    function setPoolAddressesProvider(address poolAddressesProvider_) external onlyOwner {
        address oldProvider = AccountantAaveV3Storage.getAccountantAaveV3Storage().poolAddressesProvider;
        AccountantAaveV3Storage.setPoolAddressesProvider(poolAddressesProvider_);
        emit PoolAddressesProviderUpdated(oldProvider, poolAddressesProvider_);
    }

    /**
     * @notice Sets the list of assets that are being lent on Aave V3
     * @param lendAssets_ Array of asset addresses being lent
     */
    function setLendAssets(address[] memory lendAssets_) external onlyOwner {
        address[] memory oldAssets = AccountantAaveV3Storage.getAccountantAaveV3Storage().lendAssets;
        AccountantAaveV3Storage.setLendAssets(lendAssets_);
        emit LendAssetsUpdated(oldAssets, lendAssets_);
    }

    /**
     * @notice Sets the list of assets that are being borrowed on Aave V3
     * @param borrowAssets_ Array of asset addresses being borrowed
     */
    function setBorrowAssets(address[] memory borrowAssets_) external onlyOwner {
        address[] memory oldAssets = AccountantAaveV3Storage.getAccountantAaveV3Storage().borrowAssets;
        AccountantAaveV3Storage.setBorrowAssets(borrowAssets_);
        emit BorrowAssetsUpdated(oldAssets, borrowAssets_);
    }

    /**
     * @notice Sets the performance fee rate in basis points
     * @param performanceFee_ Performance fee in basis points (BPS)
     */
    function setPerformanceFee(uint16 performanceFee_) external onlyOwner {
        uint16 oldFee = AccountantAaveV3Storage.getAccountantAaveV3Storage().performanceFee;
        AccountantAaveV3Storage.setPerformanceFee(performanceFee_);
        emit PerformanceFeeUpdated(oldFee, performanceFee_);
    }

    /**
     * @notice Sets the vault address that this accountant is associated with
     * @param vault_ Address of the Superloop vault
     */
    function setVault(address vault_) external onlyOwner {
        address oldVault = AccountantAaveV3Storage.getAccountantAaveV3Storage().vault;
        AccountantAaveV3Storage.setVault(vault_);
        emit VaultUpdated(oldVault, vault_);
    }

    function poolAddressesProvider() external view returns (address) {
        return AccountantAaveV3Storage.getAccountantAaveV3Storage().poolAddressesProvider;
    }

    function lendAssets() external view returns (address[] memory) {
        return AccountantAaveV3Storage.getAccountantAaveV3Storage().lendAssets;
    }

    function borrowAssets() external view returns (address[] memory) {
        return AccountantAaveV3Storage.getAccountantAaveV3Storage().borrowAssets;
    }

    function performanceFee() external view returns (uint16) {
        return AccountantAaveV3Storage.getAccountantAaveV3Storage().performanceFee;
    }

    function vault() external view returns (address) {
        return AccountantAaveV3Storage.getAccountantAaveV3Storage().vault;
    }

    function lastRealizedFeeExchangeRate() external view returns (uint256) {
        return AccountantAaveV3Storage.getAccountantAaveV3Storage().lastRealizedFeeExchangeRate;
    }
}
