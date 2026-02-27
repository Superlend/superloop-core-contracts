// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAaveV3AccountantPlugin} from "../../interfaces/IAaveV3AccountantPlugin.sol";
import {AaveV3AccountantPluginStorage} from "../../core/lib/AaveV3AccountantPluginStorage.sol";

/**
 * @title AaveV3AccountantPluginBase
 * @author Superlend
 * @notice Base contract for Aave V3 accountant plugin providing configuration management
 * @dev Handles Aave V3 integration settings including pool provider and asset configurations
 */
abstract contract AaveV3AccountantPluginBase is Ownable, IAaveV3AccountantPlugin {
    event PoolAddressesProviderUpdated(address indexed oldProvider, address indexed newProvider);
    event LendAssetsUpdated(address[] oldAssets, address[] newAssets);
    event BorrowAssetsUpdated(address[] oldAssets, address[] newAssets);

    constructor(address owner) Ownable(owner) {}

    function setPoolAddressesProvider(address poolAddressesProvider_) external onlyOwner {
        address oldProvider = AaveV3AccountantPluginStorage.getAaveV3AccountantPluginStorage().poolAddressesProvider;
        AaveV3AccountantPluginStorage.setPoolAddressesProvider(poolAddressesProvider_);
        emit PoolAddressesProviderUpdated(oldProvider, poolAddressesProvider_);
    }

    function setLendAssets(address[] memory lendAssets_) external onlyOwner {
        address[] memory oldAssets = AaveV3AccountantPluginStorage.getAaveV3AccountantPluginStorage().lendAssets;
        AaveV3AccountantPluginStorage.setLendAssets(lendAssets_);
        emit LendAssetsUpdated(oldAssets, lendAssets_);
    }

    function setBorrowAssets(address[] memory borrowAssets_) external onlyOwner {
        address[] memory oldAssets = AaveV3AccountantPluginStorage.getAaveV3AccountantPluginStorage().borrowAssets;
        AaveV3AccountantPluginStorage.setBorrowAssets(borrowAssets_);
        emit BorrowAssetsUpdated(oldAssets, borrowAssets_);
    }

    function poolAddressesProvider() external view returns (address) {
        return AaveV3AccountantPluginStorage.getAaveV3AccountantPluginStorage().poolAddressesProvider;
    }

    function lendAssets() external view returns (address[] memory) {
        return AaveV3AccountantPluginStorage.getAaveV3AccountantPluginStorage().lendAssets;
    }

    function borrowAssets() external view returns (address[] memory) {
        return AaveV3AccountantPluginStorage.getAaveV3AccountantPluginStorage().borrowAssets;
    }
}
