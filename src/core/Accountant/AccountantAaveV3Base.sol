// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {AccountantAaveV3Storage} from "../lib/AccountantAaveV3Storage.sol";

abstract contract AccountantAaveV3Base is OwnableUpgradeable {
    function __AccountantAaveV3Base_init(address owner) internal onlyInitializing {
        __Ownable_init(owner);
    }

    function setPoolAddressesProvider(address poolAddressesProvider_) external onlyOwner {
        AccountantAaveV3Storage.setPoolAddressesProvider(poolAddressesProvider_);
    }

    function setLendAssets(address[] memory lendAssets_) external onlyOwner {
        AccountantAaveV3Storage.setLendAssets(lendAssets_);
    }

    function setBorrowAssets(address[] memory borrowAssets_) external onlyOwner {
        AccountantAaveV3Storage.setBorrowAssets(borrowAssets_);
    }

    function setPerformanceFee(uint16 performanceFee_) external onlyOwner {
        AccountantAaveV3Storage.setPerformanceFee(performanceFee_);
    }

    function setVault(address vault_) external onlyOwner {
        AccountantAaveV3Storage.setVault(vault_);
    }
}
