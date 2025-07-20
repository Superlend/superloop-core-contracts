// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Errors} from "../../common/Errors.sol";

library SuperloopAccountantAaveV3ModuleStorage {
    uint256 constant BPS_DENOMINATOR = 10000;
    uint16 constant PERFORMANCE_FEE_CAP = 5000; // 50%

    struct SuperloopAccountantAaveV3ModuleState {
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

    function getSuperloopAccountantAaveV3ModuleStorage()
        internal
        pure
        returns (SuperloopAccountantAaveV3ModuleState storage $)
    {
        assembly {
            $.slot := SuperloopStateStorageLocation
        }
    }

    function setPoolAddressesProvider(address poolAddressesProvider_) internal {
        SuperloopAccountantAaveV3ModuleState
            storage $ = getSuperloopAccountantAaveV3ModuleStorage();
        $.poolAddressesProvider = poolAddressesProvider_;
    }

    function setLendAssets(address[] memory lendAssets_) internal {
        SuperloopAccountantAaveV3ModuleState
            storage $ = getSuperloopAccountantAaveV3ModuleStorage();
        $.lendAssets = lendAssets_;
    }

    function setBorrowAssets(address[] memory borrowAssets_) internal {
        SuperloopAccountantAaveV3ModuleState
            storage $ = getSuperloopAccountantAaveV3ModuleStorage();
        $.borrowAssets = borrowAssets_;
    }

    function setPerformanceFee(uint16 performanceFee_) internal {
        if (performanceFee_ > PERFORMANCE_FEE_CAP) {
            revert(Errors.INVALID_PERFORMANCE_FEE);
        }

        SuperloopAccountantAaveV3ModuleState
            storage $ = getSuperloopAccountantAaveV3ModuleStorage();
        $.performanceFee = performanceFee_;
    }

    function setLastRealizedFeeExchangeRate(
        uint256 lastRealizedFeeExchangeRate_
    ) internal {
        SuperloopAccountantAaveV3ModuleState
            storage $ = getSuperloopAccountantAaveV3ModuleStorage();
        $.lastRealizedFeeExchangeRate = lastRealizedFeeExchangeRate_;
    }

    function setVault(address vault_) internal {
        SuperloopAccountantAaveV3ModuleState
            storage $ = getSuperloopAccountantAaveV3ModuleStorage();
        $.vault = vault_;
    }
}
