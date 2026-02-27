// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Errors} from "../../common/Errors.sol";

library AccountantAaveV3Storage {
    uint256 constant BPS_DENOMINATOR = 10000;
    uint16 constant PERFORMANCE_FEE_CAP = 5000; // 50%

    struct AccountantAaveV3State {
        address poolAddressesProvider;
        address[] lendAssets;
        address[] borrowAssets;
        uint16 performanceFee; // BPS
        uint256 lastRealizedFeeExchangeRate;
        address vault;
    }

    /**
     * @dev Storage location constant for the superloop storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.superloopAccountantAaveV3Module.storage")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SuperloopStateStorageLocation =
        0x598833bb6e5b117dbde0d7085bdc6742e065fbf9b5d0a2add3a41c4c0587f600;

    function getAccountantAaveV3Storage() internal pure returns (AccountantAaveV3State storage $) {
        assembly {
            $.slot := SuperloopStateStorageLocation
        }
    }

    function setPoolAddressesProvider(address poolAddressesProvider_) internal {
        AccountantAaveV3State storage $ = getAccountantAaveV3Storage();
        $.poolAddressesProvider = poolAddressesProvider_;
    }

    function setLendAssets(address[] memory lendAssets_) internal {
        AccountantAaveV3State storage $ = getAccountantAaveV3Storage();
        $.lendAssets = lendAssets_;
    }

    function setBorrowAssets(address[] memory borrowAssets_) internal {
        AccountantAaveV3State storage $ = getAccountantAaveV3Storage();
        $.borrowAssets = borrowAssets_;
    }

    function setPerformanceFee(uint16 performanceFee_) internal {
        if (performanceFee_ > PERFORMANCE_FEE_CAP) {
            revert(Errors.INVALID_PERFORMANCE_FEE);
        }

        AccountantAaveV3State storage $ = getAccountantAaveV3Storage();
        $.performanceFee = performanceFee_;
    }

    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_) internal {
        AccountantAaveV3State storage $ = getAccountantAaveV3Storage();
        $.lastRealizedFeeExchangeRate = lastRealizedFeeExchangeRate_;
    }

    function setVault(address vault_) internal {
        AccountantAaveV3State storage $ = getAccountantAaveV3Storage();
        $.vault = vault_;
    }
}
