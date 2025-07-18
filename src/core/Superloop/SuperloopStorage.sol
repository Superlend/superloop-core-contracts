// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Storages} from "../../common/Storages.sol";
import {SuperloopBase} from "./SuperloopBase.sol";
import {Errors} from "../../common/Errors.sol";

abstract contract SuperloopStorage is SuperloopBase {
    uint8 public immutable DECIMALS_OFFSET = 2;
    address public immutable SUPERLOOP_MODULE_REGISTRY;

    constructor(address superloopModuleRegistry_) {
        DECIMALS_OFFSET = 2;
        SUPERLOOP_MODULE_REGISTRY = superloopModuleRegistry_;
    }

    function _setSupplyCap(uint256 supplyCap_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.supplyCap = supplyCap_;
    }

    function _setFeeManager(address feeManager_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.feeManager = feeManager_;
    }

    function _setWithdrawManager(address withdrawManager_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.withdrawManager = withdrawManager_;
    }

    function _setCommonPriceOracle(address commonPriceOracle_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.commonPriceOracle = commonPriceOracle_;
    }

    function _setVaultAdmin(address vaultAdmin_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.vaultAdmin = vaultAdmin_;
    }

    function _setTreasury(address treasury_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.treasury = treasury_;
    }

    function _setPerformanceFee(uint16 performanceFee_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.performanceFee = performanceFee_;
    }

    function _setRegisteredModule(address module_, bool registered_) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.registeredModules[module_] = registered_;
    }

    function _setUserLastRealizedFeeExchangeRate(
        address user_,
        uint256 lastRealizedFeeExchangeRate_
    ) internal {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        $.userLastRealizedFeeExchangeRate[user_] = lastRealizedFeeExchangeRate_;
    }

    function supplyCap() internal view returns (uint256) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.supplyCap;
    }

    function feeManager() internal view returns (address) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.feeManager;
    }

    function withdrawManager() internal view returns (address) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.withdrawManager;
    }

    function commonPriceOracle() internal view returns (address) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.commonPriceOracle;
    }

    function vaultAdmin() internal view returns (address) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.vaultAdmin;
    }

    function treasury() internal view returns (address) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.treasury;
    }

    function performanceFee() internal view returns (uint16) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.performanceFee;
    }

    function registeredModules(address module_) internal view returns (bool) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.registeredModules[module_];
    }

    function userLastRealizedFeeExchangeRate(
        address user_
    ) internal view returns (uint256) {
        Storages.SuperloopState storage $ = _getSuperloopStorage();
        return $.userLastRealizedFeeExchangeRate[user_];
    }
}
