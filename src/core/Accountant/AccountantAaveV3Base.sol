// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {AccountantAaveV3Storage} from "../lib/AccountantAaveV3Storage.sol";
import {IAccountantModule} from "../../interfaces/IAccountantModule.sol";

abstract contract AccountantAaveV3Base is OwnableUpgradeable, IAccountantModule {
    event PoolAddressesProviderUpdated(address indexed oldProvider, address indexed newProvider);
    event LendAssetsUpdated(address[] oldAssets, address[] newAssets);
    event BorrowAssetsUpdated(address[] oldAssets, address[] newAssets);
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);
    event VaultUpdated(address indexed oldVault, address indexed newVault);

    function __AccountantAaveV3Base_init(address owner) internal onlyInitializing {
        __Ownable_init(owner);
    }

    function setPoolAddressesProvider(address poolAddressesProvider_) external onlyOwner {
        address oldProvider = AccountantAaveV3Storage.getAccountantAaveV3Storage().poolAddressesProvider;
        AccountantAaveV3Storage.setPoolAddressesProvider(poolAddressesProvider_);
        emit PoolAddressesProviderUpdated(oldProvider, poolAddressesProvider_);
    }

    function setLendAssets(address[] memory lendAssets_) external onlyOwner {
        address[] memory oldAssets = AccountantAaveV3Storage.getAccountantAaveV3Storage().lendAssets;
        AccountantAaveV3Storage.setLendAssets(lendAssets_);
        emit LendAssetsUpdated(oldAssets, lendAssets_);
    }

    function setBorrowAssets(address[] memory borrowAssets_) external onlyOwner {
        address[] memory oldAssets = AccountantAaveV3Storage.getAccountantAaveV3Storage().borrowAssets;
        AccountantAaveV3Storage.setBorrowAssets(borrowAssets_);
        emit BorrowAssetsUpdated(oldAssets, borrowAssets_);
    }

    function setPerformanceFee(uint16 performanceFee_) external onlyOwner {
        uint16 oldFee = AccountantAaveV3Storage.getAccountantAaveV3Storage().performanceFee;
        AccountantAaveV3Storage.setPerformanceFee(performanceFee_);
        emit PerformanceFeeUpdated(oldFee, performanceFee_);
    }

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
