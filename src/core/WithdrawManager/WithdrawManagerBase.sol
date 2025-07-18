// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Storages} from "../../common/Storages.sol";

abstract contract WithdrawManagerBase {
    /**
     * @dev Storage location constant for the withdraw manager storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.storage.WithdrawManager")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant WithdrawManagerStorageLocation =
        0x423bea3933e6a497b6fb476970c32da2d847e7ebc3511b83b7ac2aafc89c0d00;

    function _getWithdrawManagerStorage() internal pure returns (Storages.WithdrawManagerState storage $) {
        assembly {
            $.slot := WithdrawManagerStorageLocation
        }
    }
}
