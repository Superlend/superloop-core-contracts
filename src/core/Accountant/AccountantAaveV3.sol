// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {AccountantAaveV3Storage} from "../lib/AccountantAaveV3Storage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAccountantModule} from "../../interfaces/IAccountantModule.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Errors} from "../../common/Errors.sol";
import {AccountantAaveV3Base} from "./AccountantAaveV3Base.sol";

contract AccountantAaveV3 is ReentrancyGuardUpgradeable, AccountantAaveV3Base, IAccountantModule {
    constructor() {
        _disableInitializers();
    }

    function initialize(DataTypes.AaveV3AccountantModuleInitData memory data) public initializer {
        __ReentrancyGuard_init();
        __AccountantAaveV3Module_init(data);
        __AccountantAaveV3Base_init(_msgSender());
    }

    function __AccountantAaveV3Module_init(DataTypes.AaveV3AccountantModuleInitData memory data)
        internal
        onlyInitializing
    {
        AccountantAaveV3Storage.setPoolAddressesProvider(data.poolAddressesProvider);
        AccountantAaveV3Storage.setLendAssets(data.lendAssets);
        AccountantAaveV3Storage.setBorrowAssets(data.borrowAssets);
        AccountantAaveV3Storage.setPerformanceFee(data.performanceFee);
        AccountantAaveV3Storage.setVault(data.vault);
    }

    // get total assets for the contract
    function getTotalAssets() public view returns (uint256) {
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();
        address baseAsset = IERC4626($.vault).asset();

        // get poolDataProvider from poolAddressesProvider
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider($.poolAddressesProvider);
        IAaveOracle aaveOracle = IAaveOracle(poolAddressesProvider.getPriceOracle());
        IPoolDataProvider poolDataProvider = IPoolDataProvider(poolAddressesProvider.getPoolDataProvider());

        // read the lend amount from lendAssets
        uint256 len = $.lendAssets.length;
        uint256 totalAssetsInMarketReferenceCurrency = 0;
        for (uint256 i; i < len;) {
            address lendAsset = $.lendAssets[i];
            (uint256 currentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(lendAsset, $.vault);
            uint256 price = aaveOracle.getAssetPrice(lendAsset);
            totalAssetsInMarketReferenceCurrency += currentATokenBalance * price;

            unchecked {
                ++i;
            }
        }

        len = $.borrowAssets.length;
        for (uint256 i; i < len;) {
            address borrowAsset = $.borrowAssets[i];
            (,, uint256 currentVariableDebt,,,,,,) = poolDataProvider.getUserReserveData(borrowAsset, $.vault);
            uint256 price = aaveOracle.getAssetPrice(borrowAsset);
            totalAssetsInMarketReferenceCurrency -= currentVariableDebt * price;

            unchecked {
                ++i;
            }
        }

        uint256 baseAssetPrice = aaveOracle.getAssetPrice(baseAsset);
        totalAssetsInMarketReferenceCurrency += IERC20(baseAsset).balanceOf($.vault) * baseAssetPrice;

        // convert to base asset
        uint256 totalAssetsInBaseAsset = totalAssetsInMarketReferenceCurrency / baseAssetPrice;

        return totalAssetsInBaseAsset;
    }

    function getPerformanceFee(uint256 totalShares, uint256 exchangeRate, uint8 decimals)
        public
        view
        onlyVault
        returns (uint256)
    {
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();

        uint256 latestAssetAmount = totalShares * exchangeRate;
        uint256 prevAssetAmount = totalShares * $.lastRealizedFeeExchangeRate;

        if (prevAssetAmount > latestAssetAmount) return 0;

        uint256 interestGenerated = latestAssetAmount - prevAssetAmount;

        uint256 performanceFee =
            (interestGenerated * $.performanceFee) / (AccountantAaveV3Storage.BPS_DENOMINATOR * 10 ** decimals);

        return performanceFee;
    }

    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_) public onlyVault {
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();
        $.lastRealizedFeeExchangeRate = lastRealizedFeeExchangeRate_;
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();
        require(msg.sender == $.vault, Errors.CALLER_NOT_VAULT);
    }
}
