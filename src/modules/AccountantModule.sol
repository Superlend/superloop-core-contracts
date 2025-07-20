// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {SuperloopAccountantAaveV3ModuleStorage} from "../core/lib/SuperloopAccountantAaveV3ModuleStorage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAccountantModule} from "../interfaces/IAccountantModule.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Errors} from "../common/Errors.sol";

contract SuperloopAccountantAaveV3Module is
    ReentrancyGuardUpgradeable,
    IAccountantModule
{
    constructor() {
        _disableInitializers();
    }

    function initialize(
        DataTypes.AaveV3AccountantModuleInitData memory data
    ) public initializer {
        __ReentrancyGuard_init();
        __SuperloopAccountantAaveV3Module_init(data);
    }

    function __SuperloopAccountantAaveV3Module_init(
        DataTypes.AaveV3AccountantModuleInitData memory data
    ) internal onlyInitializing {
        SuperloopAccountantAaveV3ModuleStorage.setPoolAddressesProvider(
            data.poolAddressesProvider
        );
        SuperloopAccountantAaveV3ModuleStorage.setLendAssets(data.lendAssets);
        SuperloopAccountantAaveV3ModuleStorage.setBorrowAssets(
            data.borrowAssets
        );
        SuperloopAccountantAaveV3ModuleStorage.setPerformanceFee(
            data.performanceFee
        );
        SuperloopAccountantAaveV3ModuleStorage.setVault(data.vault);
    }

    // get total assets for the contract
    function getTotalAssets() public view returns (uint256) {
        SuperloopAccountantAaveV3ModuleStorage.SuperloopAccountantAaveV3ModuleState
            storage $ = SuperloopAccountantAaveV3ModuleStorage
                .getSuperloopAccountantAaveV3ModuleStorage();
        address baseAsset = IERC4626($.vault).asset();

        // get poolDataProvider from poolAddressesProvider
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(
            $.poolAddressesProvider
        );
        IAaveOracle aaveOracle = IAaveOracle(
            poolAddressesProvider.getPriceOracle()
        );
        IPoolDataProvider poolDataProvider = IPoolDataProvider(
            poolAddressesProvider.getPoolDataProvider()
        );

        // read the lend amount from lendAssets
        uint256 len = $.lendAssets.length;
        uint256 totalAssetsInMarketReferenceCurrency = 0;
        for (uint256 i; i < len; ) {
            address lendAsset = $.lendAssets[i];
            (uint256 currentATokenBalance, , , , , , , , ) = poolDataProvider
                .getUserReserveData(lendAsset, address(this));
            uint256 price = aaveOracle.getAssetPrice(lendAsset);
            totalAssetsInMarketReferenceCurrency +=
                currentATokenBalance *
                price;

            unchecked {
                ++i;
            }
        }

        len = $.borrowAssets.length;
        for (uint256 i; i < len; ) {
            address borrowAsset = $.borrowAssets[i];
            (, , uint256 currentVariableDebt, , , , , , ) = poolDataProvider
                .getUserReserveData(borrowAsset, address(this));
            uint256 price = aaveOracle.getAssetPrice(borrowAsset);
            totalAssetsInMarketReferenceCurrency -= currentVariableDebt * price;

            unchecked {
                ++i;
            }
        }

        uint256 baseAssetPrice = aaveOracle.getAssetPrice(baseAsset);
        totalAssetsInMarketReferenceCurrency +=
            IERC20(baseAsset).balanceOf(address(this)) *
            baseAssetPrice;

        // convert to base asset
        uint256 totalAssetsInBaseAsset = totalAssetsInMarketReferenceCurrency /
            baseAssetPrice;

        return totalAssetsInBaseAsset;
    }

    function getPerformanceFee(
        uint256 totalShares,
        uint256 exchangeRate
    ) public view onlyVault returns (uint256) {
        SuperloopAccountantAaveV3ModuleStorage.SuperloopAccountantAaveV3ModuleState
            storage $ = SuperloopAccountantAaveV3ModuleStorage
                .getSuperloopAccountantAaveV3ModuleStorage();

        uint256 latestAssetAmount = totalShares * exchangeRate;
        uint256 prevAssetAmount = totalShares * $.lastRealizedFeeExchangeRate;

        if (prevAssetAmount > latestAssetAmount) return 0;

        uint256 interestGenerated = latestAssetAmount - prevAssetAmount;
        uint256 performanceFee = (interestGenerated * $.performanceFee) /
            SuperloopAccountantAaveV3ModuleStorage.BPS_DENOMINATOR;

        return performanceFee;
    }

    function setLastRealizedFeeExchangeRate(
        uint256 lastRealizedFeeExchangeRate_
    ) public onlyVault {
        SuperloopAccountantAaveV3ModuleStorage.SuperloopAccountantAaveV3ModuleState
            storage $ = SuperloopAccountantAaveV3ModuleStorage
                .getSuperloopAccountantAaveV3ModuleStorage();
        $.lastRealizedFeeExchangeRate = lastRealizedFeeExchangeRate_;
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        SuperloopAccountantAaveV3ModuleStorage.SuperloopAccountantAaveV3ModuleState
            storage $ = SuperloopAccountantAaveV3ModuleStorage
                .getSuperloopAccountantAaveV3ModuleStorage();
        require(msg.sender == $.vault, Errors.CALLER_NOT_VAULT);
    }
}
