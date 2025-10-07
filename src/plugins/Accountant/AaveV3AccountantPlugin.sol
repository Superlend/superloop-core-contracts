// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {AaveV3AccountantPluginBase} from "./AaveV3AccountantPluginBase.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {AaveV3AccountantPluginStorage} from "../../core/lib/AaveV3AccountantPluginStorage.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";

contract AaveV3AccountantPlugin is AaveV3AccountantPluginBase {
    constructor(DataTypes.AaveV3AccountantPluginModuleInitData memory data) AaveV3AccountantPluginBase(_msgSender()) {
        AaveV3AccountantPluginStorage.setPoolAddressesProvider(data.poolAddressesProvider);
        AaveV3AccountantPluginStorage.setLendAssets(data.lendAssets);
        AaveV3AccountantPluginStorage.setBorrowAssets(data.borrowAssets);
    }

    struct GetVaultBalanceParams {
        address vault;
        address[] assets;
        address poolAddressesProvider;
        uint256 commonDecimalFactor;
    }

    // get total assets for the contract
    function getTotalAssets(address vault) public view returns (uint256) {
        AaveV3AccountantPluginStorage.AaveV3AccountantPluginState storage $ =
            AaveV3AccountantPluginStorage.getAaveV3AccountantPluginStorage();
        address baseAsset = IERC4626(vault).asset();
        uint8 baseDecimals = IERC20Metadata(baseAsset).decimals();
        uint256 commonDecimalFactor = 10 ** baseDecimals;

        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider($.poolAddressesProvider);
        IAaveOracle aaveOracle = IAaveOracle(poolAddressesProvider.getPriceOracle());

        uint256 baseAssetPrice = aaveOracle.getAssetPrice(baseAsset);
        uint256 positiveBalance =
            (IERC20(baseAsset).balanceOf(vault) * commonDecimalFactor * baseAssetPrice) / (10 ** baseDecimals);
        uint256 negativeBalance = 0;

        (uint256 lendBalance,) =
            _getVaultBalance(GetVaultBalanceParams(vault, $.lendAssets, $.poolAddressesProvider, commonDecimalFactor));
        (, uint256 borrowBalance) =
            _getVaultBalance(GetVaultBalanceParams(vault, $.borrowAssets, $.poolAddressesProvider, commonDecimalFactor));

        positiveBalance += lendBalance;
        negativeBalance += borrowBalance;

        // convert to base asset
        uint256 totalAssetsInBaseAsset = (positiveBalance - negativeBalance) / baseAssetPrice;

        return totalAssetsInBaseAsset;
    }

    function _getVaultBalance(GetVaultBalanceParams memory params) internal view returns (uint256, uint256) {
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(params.poolAddressesProvider);
        IAaveOracle aaveOracle = IAaveOracle(poolAddressesProvider.getPriceOracle());
        IPoolDataProvider poolDataProvider = IPoolDataProvider(poolAddressesProvider.getPoolDataProvider());

        uint256 len = params.assets.length;
        uint256 lendBalance = 0;
        uint256 borrowBalance = 0;
        for (uint256 i; i < len;) {
            address asset = params.assets[i];
            (uint256 currentATokenBalance,, uint256 currentVariableDebt,,,,,,) =
                poolDataProvider.getUserReserveData(asset, params.vault);
            uint256 price = aaveOracle.getAssetPrice(asset);
            uint8 decimals = IERC20Metadata(asset).decimals();
            uint256 lendBalanceFormatted =
                (currentATokenBalance * params.commonDecimalFactor * price) / (10 ** decimals);
            uint256 borrowBalanceFormatted =
                (currentVariableDebt * params.commonDecimalFactor * price) / (10 ** decimals);
            lendBalance += lendBalanceFormatted;
            borrowBalance += borrowBalanceFormatted;

            unchecked {
                ++i;
            }
        }

        return (lendBalance, borrowBalance);
    }
}
