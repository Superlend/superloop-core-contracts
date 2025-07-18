// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SuperloopAccountantAaveV3Base} from "./AccountantBase.sol";
import {Storages} from "../../common/Storages.sol";
import {Errors} from "../../common/Errors.sol";

abstract contract SuperloopAccountantAaveV3Storage is SuperloopAccountantAaveV3Base {
    uint16 public constant MAX_PERFORMANCE_FEE = 1000; // 10%

    function _setPoolAddressesProvider(address poolAddressesProvider_) internal {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        $.poolAddressesProvider = poolAddressesProvider_;
    }

    function _setLendAssets(address[] memory lendAssets_) internal {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        $.lendAssets = lendAssets_;
    }

    function _setBorrowAssets(address[] memory borrowAssets_) internal {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        $.borrowAssets = borrowAssets_;
    }

    function _setOraclePriceStandard(address oraclePriceStandard_) internal {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        $.oraclePriceStandard = oraclePriceStandard_;
    }

    function _setPerformanceFee(uint16 performanceFee_) internal {
        require(performanceFee_ <= MAX_PERFORMANCE_FEE, Errors.INVALID_PERFORMANCE_FEE);

        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        $.performanceFee = performanceFee_;
    }

    function _setUserLastRealizedFeeExchangeRate(address user, uint256 lastRealizedFeeExchangeRate) internal {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        $.userLastRealizedFeeExchangeRate[user] = lastRealizedFeeExchangeRate;
    }

    function poolAddressesProvider() public view returns (address) {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        return $.poolAddressesProvider;
    }

    function lendAssets() public view returns (address[] memory) {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        return $.lendAssets;
    }

    function borrowAssets() public view returns (address[] memory) {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        return $.borrowAssets;
    }

    function oraclePriceStandard() public view returns (address) {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        return $.oraclePriceStandard;
    }

    function performanceFee() public view returns (uint16) {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        return $.performanceFee;
    }

    function userLastRealizedFeeExchangeRate(address user) public view returns (uint256) {
        Storages.SuperloopAccountantAaveV3State storage $ = _getSuperloopAccountantAaveV3Storage();
        return $.userLastRealizedFeeExchangeRate[user];
    }
}
