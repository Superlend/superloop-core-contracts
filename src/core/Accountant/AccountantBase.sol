// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Storages} from "../../common/Storages.sol";

abstract contract SuperloopAccountantAaveV3Base {
    /**
     * @dev Storage location constant for the Aave V3 accountant storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.storage.SuperloopAccountantAaveV3")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopAccountantAaveV3StorageLocation =
        0xa0264b2a78623abddf3653255f5ab244f9fc4725c1536a4039c89401faf3fb00;

    function _getSuperloopAccountantAaveV3Storage()
        internal
        pure
        returns (Storages.SuperloopAccountantAaveV3State storage $)
    {
        assembly {
            $.slot := SuperloopAccountantAaveV3StorageLocation
        }
    }
}
