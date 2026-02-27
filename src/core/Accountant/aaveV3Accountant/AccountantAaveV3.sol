// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {
    ReentrancyGuardUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {AccountantAaveV3Storage} from "../../lib/AccountantAaveV3Storage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Errors} from "../../../common/Errors.sol";
import {AccountantAaveV3Base} from "./AccountantAaveV3Base.sol";

/**
 * @title AccountantAaveV3
 * @author Superlend
 * @notice Manages total assets calculation and performance fee tracking for Aave V3 positions
 * @dev Calculates total assets by aggregating lending positions, subtracting borrowing positions, and converting to base asset using Aave oracle prices
 */
contract AccountantAaveV3 is ReentrancyGuardUpgradeable, AccountantAaveV3Base {
    event LastRealizedFeeExchangeRateUpdated(uint256 oldRate, uint256 newRate);

    constructor() {
        _disableInitializers();
    }

    function initialize(DataTypes.AaveV3AccountantModuleInitData memory data) public initializer {
        __ReentrancyGuard_init();
        __AccountantAaveV3Module_init(data);
        __AccountantAaveV3Base_init(_msgSender());
    }

    /**
     * @notice Initializes the AccountantAaveV3 module with Aave V3 configuration
     * @param data Initialization data containing pool addresses provider, lend/borrow assets, performance fee, and vault address
     */
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

    /**
     * @notice Calculates total assets by aggregating Aave V3 positions and converting to base asset
     * @return Total assets value in base asset terms
     * @dev Sums lending positions (positive balance), subtracts borrowing positions (negative balance), adds base asset balance, and converts to base asset using oracle prices
     */
    function getTotalAssets() public view returns (uint256) {
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();
        address baseAsset = IERC4626($.vault).asset();
        uint8 baseDecimals = IERC20Metadata(baseAsset).decimals();
        uint256 commonDecimalFactor = 10 ** baseDecimals;

        // get poolDataProvider from poolAddressesProvider
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider($.poolAddressesProvider);
        IAaveOracle aaveOracle = IAaveOracle(poolAddressesProvider.getPriceOracle());
        IPoolDataProvider poolDataProvider = IPoolDataProvider(poolAddressesProvider.getPoolDataProvider());

        // read the lend amount from lendAssets
        uint256 len = $.lendAssets.length;
        uint256 positiveBalance = 0;
        uint256 negativeBalance = 0;
        for (uint256 i; i < len;) {
            address lendAsset = $.lendAssets[i];
            (uint256 currentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(lendAsset, $.vault);
            uint256 price = aaveOracle.getAssetPrice(lendAsset);
            uint8 decimals = IERC20Metadata(lendAsset).decimals();
            uint256 balanceFormatted = (currentATokenBalance * commonDecimalFactor * price) / (10 ** decimals);
            positiveBalance += balanceFormatted;

            unchecked {
                ++i;
            }
        }

        // sum all borrowing positions
        len = $.borrowAssets.length;
        for (uint256 i; i < len;) {
            address borrowAsset = $.borrowAssets[i];
            (,, uint256 currentVariableDebt,,,,,,) = poolDataProvider.getUserReserveData(borrowAsset, $.vault);
            uint256 price = aaveOracle.getAssetPrice(borrowAsset);
            uint8 decimals = IERC20Metadata(borrowAsset).decimals();
            uint256 balanceFormatted = (currentVariableDebt * commonDecimalFactor * price) / (10 ** decimals);
            negativeBalance += balanceFormatted;

            unchecked {
                ++i;
            }
        }

        // add base asset balance held in vault
        uint256 baseAssetPrice = aaveOracle.getAssetPrice(baseAsset);
        positiveBalance += (IERC20(baseAsset).balanceOf($.vault) * commonDecimalFactor * baseAssetPrice)
            / (10 ** baseDecimals);

        // convert to base asset
        uint256 totalAssetsInBaseAsset = (positiveBalance - negativeBalance) / baseAssetPrice;

        return totalAssetsInBaseAsset;
    }

    /**
     * @notice Calculates the performance fee based on exchange rate appreciation
     * @param totalShares Total number of shares in the vault
     * @param exchangeRate Current exchange rate (assets per share)
     * @param decimals Decimal precision for the calculation
     * @return Performance fee amount in base asset terms
     * @dev Calculates fee only on positive performance (when current rate > last realized rate)
     */
    function getPerformanceFee(uint256 totalShares, uint256 exchangeRate, uint8 decimals)
        public
        view
        onlyVault
        returns (uint256)
    {
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();

        uint256 latestAssetAmount = totalShares * exchangeRate;
        uint256 prevAssetAmount = totalShares * $.lastRealizedFeeExchangeRate;

        // return 0 if there's no positive performance
        if (prevAssetAmount > latestAssetAmount) return 0;

        uint256 interestGenerated = latestAssetAmount - prevAssetAmount;

        uint256 performanceFee =
            (interestGenerated * $.performanceFee) / (AccountantAaveV3Storage.BPS_DENOMINATOR * 10 ** decimals);

        return performanceFee;
    }

    /**
     * @notice Updates the last realized fee exchange rate after performance fee collection
     * @param lastRealizedFeeExchangeRate_ New exchange rate to set as the last realized rate
     * @param totalSupply Total supply of shares in the vault
     * @dev Only allows rate updates that are higher than the previous rate (unless totalSupply is 0)
     */
    function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_, uint256 totalSupply)
        public
        onlyVault
    {
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();

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
        AccountantAaveV3Storage.AccountantAaveV3State storage $ = AccountantAaveV3Storage.getAccountantAaveV3Storage();
        require(msg.sender == $.vault, Errors.CALLER_NOT_VAULT);
    }
}
