// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Storages} from "../../common/Storages.sol";

abstract contract SuperloopBase {
    /**
     * @dev Storage location constant for the superloop storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.storage.Superloop")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopStorageLocation =
        0x7342146a526b3b84c4d05641666cb2b0fcedad328645911961c67d0832ae3400;

    function _getSuperloopStorage() internal pure returns (Storages.SuperloopState storage $) {
        assembly {
            $.slot := SuperloopStorageLocation
        }
    }
}
