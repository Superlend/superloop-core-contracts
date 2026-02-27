// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Errors} from "../../common/Errors.sol";

library UniversalAccountantStorage {
    uint256 constant BPS_DENOMINATOR = 10000;
    uint16 constant PERFORMANCE_FEE_CAP = 5000; // 50%

    struct UniversalAccountantState {
        address[] registeredAccountants;
        uint16 performanceFee; // BPS
        uint256 lastRealizedFeeExchangeRate;
        address vault;
    }

    /**
     * @dev Storage location constant for the superloop storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.superloopUniversalAccountantModule.storage")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopUniversalAccountantStateStorageLocation =
        0x783f2e9471ce6cf778bf616a7ac4412c31a83a959ebb7593a05041db1bd62900;

    function getUniversalAccountantStorage() internal pure returns (UniversalAccountantState storage $) {
        assembly {
            $.slot := SuperloopUniversalAccountantStateStorageLocation
        }
    }

    function setRegisteredAccountants(address[] memory registeredAccountants_) internal {
        UniversalAccountantState storage $ = getUniversalAccountantStorage();
        $.registeredAccountants = registeredAccountants_;
    }

    function setPerformanceFee(uint16 performanceFee_) internal {
        if (performanceFee_ > PERFORMANCE_FEE_CAP) {
            revert(Errors.INVALID_PERFORMANCE_FEE);
        }

        UniversalAccountantState storage $ = getUniversalAccountantStorage();
        $.performanceFee = performanceFee_;
    }

    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_) internal {
        UniversalAccountantState storage $ = getUniversalAccountantStorage();
        $.lastRealizedFeeExchangeRate = lastRealizedFeeExchangeRate_;
    }

    function setVault(address vault_) internal {
        UniversalAccountantState storage $ = getUniversalAccountantStorage();
        $.vault = vault_;
    }
}
