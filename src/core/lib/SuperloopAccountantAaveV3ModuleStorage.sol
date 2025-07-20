// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library SuperloopAccountantAaveV3ModuleStorage {
    struct SuperloopAccountantAaveV3ModuleState {
        address poolAddressesProvider;
        address[] lendAssets;
        address[] borrowAssets;
        address oraclePriceStandard;
        uint16 performanceFee; // BPS
        mapping(address => uint256) userLastRealizedFeeExchangeRate;
    }
}
