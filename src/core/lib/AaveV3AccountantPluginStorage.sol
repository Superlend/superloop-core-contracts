// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Errors} from "../../common/Errors.sol";

library AaveV3AccountantPluginStorage {
    struct AaveV3AccountantPluginState {
        address poolAddressesProvider;
        address[] lendAssets;
        address[] borrowAssets;
    }

    /**
     * @dev Storage location constant for the superloop storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.superloopAaveV3AccountantPlugin.storage")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopAaveV3AccountantPluginStateStorageLocation =
        0x2d9aaf80da17cf02146c654915824032a8cdba656196ead8bbc96026b35a2900;

    function getAaveV3AccountantPluginStorage() internal pure returns (AaveV3AccountantPluginState storage $) {
        assembly {
            $.slot := SuperloopAaveV3AccountantPluginStateStorageLocation
        }
    }

    function setPoolAddressesProvider(address poolAddressesProvider_) internal {
        AaveV3AccountantPluginState storage $ = getAaveV3AccountantPluginStorage();
        $.poolAddressesProvider = poolAddressesProvider_;
    }

    function setLendAssets(address[] memory lendAssets_) internal {
        AaveV3AccountantPluginState storage $ = getAaveV3AccountantPluginStorage();
        $.lendAssets = lendAssets_;
    }

    function setBorrowAssets(address[] memory borrowAssets_) internal {
        AaveV3AccountantPluginState storage $ = getAaveV3AccountantPluginStorage();
        $.borrowAssets = borrowAssets_;
    }
}
