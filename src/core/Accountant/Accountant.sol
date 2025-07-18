// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {SuperloopAccountantAaveV3Storage} from "./AccountantStorage.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract SuperloopAccountantAaveV3 is
    SuperloopAccountantAaveV3Storage,
    Initializable
{
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address poolAddressesProvider_,
        address[] memory lendAssets_,
        address[] memory borrowAssets_,
        address oraclePriceStandard_,
        uint16 performanceFee_
    ) public initializer {
        __SuperloopAccountantAaveV3_init(
            poolAddressesProvider_,
            lendAssets_,
            borrowAssets_,
            oraclePriceStandard_,
            performanceFee_
        );
    }

    function __SuperloopAccountantAaveV3_init(
        address poolAddressesProvider_,
        address[] memory lendAssets_,
        address[] memory borrowAssets_,
        address oraclePriceStandard_,
        uint16 performanceFee_
    ) internal onlyInitializing {
        _setPoolAddressesProvider(poolAddressesProvider_);
        _setLendAssets(lendAssets_);
        _setBorrowAssets(borrowAssets_);
        _setOraclePriceStandard(oraclePriceStandard_);
        _setPerformanceFee(performanceFee_);
    }
}
