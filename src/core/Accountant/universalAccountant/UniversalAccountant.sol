// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {UniversalAccountantBase} from "./UniversalAccountantBase.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {UniversalAccountantStorage} from "../../lib/UniversalAccountantStorage.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {Errors} from "../../../common/Errors.sol";
import {IAaveV3AccountantPlugin} from "../../../interfaces/IAaveV3AccountantPlugin.sol";

contract UniversalAccountant is UniversalAccountantBase, ReentrancyGuardUpgradeable {
    event LastRealizedFeeExchangeRateUpdated(uint256 oldRate, uint256 newRate);

    constructor() {
        _disableInitializers();
    }

    function initialize(DataTypes.UniversalAccountantModuleInitData memory data) public initializer {
        __ReentrancyGuard_init();
        __UniversalAccountantModule_init(data);
        __UniversalAccountantBase_init(_msgSender());
    }

    function __UniversalAccountantModule_init(DataTypes.UniversalAccountantModuleInitData memory data)
        internal
        onlyInitializing
    {
        UniversalAccountantStorage.setRegisteredAccountants(data.registeredAccountants);
        UniversalAccountantStorage.setPerformanceFee(data.performanceFee);
        UniversalAccountantStorage.setVault(data.vault);
    }

    function getTotalAssets() public view returns (uint256) {
        UniversalAccountantStorage.UniversalAccountantState storage $ =
            UniversalAccountantStorage.getUniversalAccountantStorage();
        address[] memory registeredAccountants = $.registeredAccountants;
        address vault = $.vault;
        uint256 totalAssets = 0;
        for (uint256 i; i < registeredAccountants.length;) {
            totalAssets += IAaveV3AccountantPlugin(registeredAccountants[i]).getTotalAssets(vault);
            unchecked {
                ++i;
            }
        }
        return totalAssets;
    }

    function getPerformanceFee(uint256 totalShares, uint256 exchangeRate, uint8 decimals)
        public
        view
        onlyVault
        returns (uint256)
    {
        UniversalAccountantStorage.UniversalAccountantState storage $ =
            UniversalAccountantStorage.getUniversalAccountantStorage();

        uint256 latestAssetAmount = totalShares * exchangeRate;
        uint256 prevAssetAmount = totalShares * $.lastRealizedFeeExchangeRate;

        if (prevAssetAmount > latestAssetAmount) return 0;

        uint256 interestGenerated = latestAssetAmount - prevAssetAmount;

        uint256 performanceFee =
            (interestGenerated * $.performanceFee) / (UniversalAccountantStorage.BPS_DENOMINATOR * 10 ** decimals);

        return performanceFee;
    }

    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_, uint256 totalSupply)
        public
        onlyVault
    {
        UniversalAccountantStorage.UniversalAccountantState storage $ =
            UniversalAccountantStorage.getUniversalAccountantStorage();

        uint256 oldRate = $.lastRealizedFeeExchangeRate;
        // if totalSupply is 0, allow setting the last realized fee exchange rate to default
        if (totalSupply != 0 && lastRealizedFeeExchangeRate_ <= oldRate) return;

        $.lastRealizedFeeExchangeRate = lastRealizedFeeExchangeRate_;
        emit LastRealizedFeeExchangeRateUpdated(oldRate, lastRealizedFeeExchangeRate_);
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        UniversalAccountantStorage.UniversalAccountantState storage $ =
            UniversalAccountantStorage.getUniversalAccountantStorage();
        require(msg.sender == $.vault, Errors.CALLER_NOT_VAULT);
    }
}
