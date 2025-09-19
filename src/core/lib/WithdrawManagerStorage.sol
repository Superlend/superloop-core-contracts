// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";

library WithdrawManagerStorage {
    struct WithdrawQueue {
        uint256 nextWithdrawRequestId;
        uint256 resolutionIdPointer;
        mapping(uint256 => DataTypes.WithdrawRequestDataLegacy) withdrawRequest;
        mapping(address => uint256) userWithdrawRequestId;
    }

    struct WithdrawManagerState {
        address vault;
        address asset;
        uint8 vaultDecimalOffset;
        WithdrawQueue generalQueue;
        WithdrawQueue lowSlippageQueue;
        WithdrawQueue mediumSlippageQueue;
        WithdrawQueue highSlippageQueue;
    }

    /**
     * @dev Storage location constant for the withdraw manager storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.storage.WithdrawManager")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant WithdrawManagerStorageLocation =
        0x423bea3933e6a497b6fb476970c32da2d847e7ebc3511b83b7ac2aafc89c0d00;

    function getWithdrawManagerStorage() internal pure returns (WithdrawManagerState storage $) {
        assembly {
            $.slot := WithdrawManagerStorageLocation
        }
    }


    
    
}
