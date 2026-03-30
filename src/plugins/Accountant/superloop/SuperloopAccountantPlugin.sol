// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {SuperloopAccountantPluginBase} from "./SuperloopAccountantPluginBase.sol";
import {ISuperloop} from "../../../interfaces/ISuperloop.sol";
import {IDepositManager} from "../../../interfaces/IDepositManager.sol";
import {IWithdrawManager} from "../../../interfaces/IWithdrawManager.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC4626, IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {SuperloopAccountantPluginStorage} from "../../../core/lib/SuperloopAccountantPluginStorage.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";

contract SuperloopAccountantPlugin is SuperloopAccountantPluginBase {
    constructor(DataTypes.SuperloopAccountantPluginModuleInitData memory data)
        SuperloopAccountantPluginBase(_msgSender())
    {
        SuperloopAccountantPluginStorage.setUnderlyingVault(data.underlyingVault);
        SuperloopAccountantPluginStorage.setAaveOracle(data.aaveOracle);
    }

    function getTotalAssets(address vault) external view returns (uint256) {
        SuperloopAccountantPluginStorage.SuperloopAccountantPluginState storage $ =
            SuperloopAccountantPluginStorage.getSuperloopAccountantPluginStorage();

        address underlyingVault = $.underlyingVault;
        uint8 underlyingVaultDecimals = IERC4626(underlyingVault).decimals();
        address underlyingAsset = IERC4626(underlyingVault).asset();
        uint8 underlyingAssetDecimals = IERC20Metadata(underlyingAsset).decimals();
        uint256 ONE_SHARE = 10 ** underlyingVaultDecimals;
        uint256 exchangeRate = IERC4626(underlyingVault).convertToAssets(ONE_SHARE);

        address baseAsset = IERC4626(vault).asset();
        uint8 baseAssetDecimals = IERC20Metadata(baseAsset).decimals();

        uint256 underlyingAssetPrice = IAaveOracle($.aaveOracle).getAssetPrice(underlyingAsset);
        uint256 baseAssetPrice = IAaveOracle($.aaveOracle).getAssetPrice(baseAsset);

        GetAssetsFromManagerParams memory params = GetAssetsFromManagerParams({
            // underlying vault stuff
            vault: underlyingVault,
            vaultDecimals: underlyingVaultDecimals,
            exchangeRate: exchangeRate,
            underlyingAssetPrice: underlyingAssetPrice,
            underlyingAssetDecimals: underlyingAssetDecimals,
            underlyingAsset: underlyingAsset,
            // query vault stuff
            queryVault: vault,
            baseAssetPrice: baseAssetPrice,
            baseAssetDecimals: baseAssetDecimals
        });

        uint256 assetsFromWithdrawQueues = _getAssetsFromWithdrawManager(params);
        uint256 assetsFromDepositQueues = _getAssetsFromDepositManager(params);
        uint256 assetsFromUnderlyingVault = _getAssetsFromUnderlyingVault(params);
        uint256 idleUnderlyingVaultAssets = _getIdleUnderlyingVaultAssets(params);

        uint256 totalAssets =
            assetsFromWithdrawQueues + assetsFromDepositQueues + assetsFromUnderlyingVault + idleUnderlyingVaultAssets;

        return totalAssets;
    }

    struct GetAssetsFromManagerParams {
        address vault;
        uint8 vaultDecimals;
        uint256 exchangeRate;
        uint256 underlyingAssetPrice;
        uint256 underlyingAssetDecimals;
        address underlyingAsset;

        address queryVault;
        uint256 baseAssetPrice;
        uint256 baseAssetDecimals;
    }

    function _getIdleUnderlyingVaultAssets(GetAssetsFromManagerParams memory params) internal view returns (uint256) {
        // get the balance of underlying asset in the vault
        uint256 idleUnderlyingVaultAssets = IERC20(params.underlyingAsset).balanceOf(params.queryVault);

        if (idleUnderlyingVaultAssets == 0) return 0;

        return Math.mulDiv(
            idleUnderlyingVaultAssets * params.underlyingAssetPrice,
            10 ** params.baseAssetDecimals,
            params.baseAssetPrice * 10 ** params.underlyingAssetDecimals
        );
    }

    function _getAssetsFromWithdrawManager(GetAssetsFromManagerParams memory params) internal view returns (uint256) {
        IWithdrawManager withdrawManager = IWithdrawManager(ISuperloop(params.vault).withdrawManager());

        uint256 totalAmount;
        totalAmount += _getUnprocessedWithdrawAmount(withdrawManager, params, DataTypes.WithdrawRequestType.GENERAL);
        totalAmount += _getUnprocessedWithdrawAmount(withdrawManager, params, DataTypes.WithdrawRequestType.DEFERRED);
        totalAmount += _getUnprocessedWithdrawAmount(withdrawManager, params, DataTypes.WithdrawRequestType.PRIORITY);
        totalAmount += _getUnprocessedWithdrawAmount(withdrawManager, params, DataTypes.WithdrawRequestType.INSTANT);

        if (totalAmount == 0) return 0;

        return Math.mulDiv(
            totalAmount * params.underlyingAssetPrice,
            10 ** params.baseAssetDecimals,
            params.baseAssetPrice * 10 ** params.underlyingAssetDecimals
        );
    }

    /// @dev Returns the underlying-asset-denominated amount still owed for a single withdraw request queue.
    function _getUnprocessedWithdrawAmount(
        IWithdrawManager withdrawManager,
        GetAssetsFromManagerParams memory params,
        DataTypes.WithdrawRequestType requestType
    ) private view returns (uint256) {
        (DataTypes.WithdrawRequestData memory req,) =
            withdrawManager.userWithdrawRequest(params.queryVault, requestType);

        DataTypes.RequestProcessingState state = req.state;
        if (
            state != DataTypes.RequestProcessingState.UNPROCESSED
                && state != DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
                && state != DataTypes.RequestProcessingState.FULLY_PROCESSED
        ) {
            return 0;
        }

        uint256 remainingShares = req.shares - req.sharesProcessed;
        uint256 amountFromShares = remainingShares * params.exchangeRate / 10 ** params.vaultDecimals;
        return amountFromShares + req.amountClaimable;
    }

    function _getAssetsFromDepositManager(GetAssetsFromManagerParams memory params) internal view returns (uint256) {
        IDepositManager depositManager = IDepositManager(ISuperloop(params.vault).depositManagerModule());

        (DataTypes.DepositRequestData memory depositRequest,) = depositManager.userDepositRequest(params.queryVault);

        // if there is a pending or partially processed request, then use the
        //amount of tokens left to be processed, because rest shares worth rest of the tokens are already minted to the user
        DataTypes.RequestProcessingState state = depositRequest.state;
        if (
            state != DataTypes.RequestProcessingState.UNPROCESSED
                && state != DataTypes.RequestProcessingState.PARTIALLY_PROCESSED
        ) {
            return 0;
        }

        uint256 unprocessedAmount = depositRequest.amount - depositRequest.amountProcessed;
        if (unprocessedAmount == 0) return 0;

        return Math.mulDiv(
            unprocessedAmount * params.underlyingAssetPrice,
            10 ** params.baseAssetDecimals,
            params.baseAssetPrice * 10 ** params.underlyingAssetDecimals
        );
    }

    function _getAssetsFromUnderlyingVault(GetAssetsFromManagerParams memory params) internal view returns (uint256) {
        uint256 totalShares = IERC4626(params.vault).balanceOf(params.queryVault);
        uint256 amountFromShares = totalShares * params.exchangeRate / 10 ** params.vaultDecimals;

        return Math.mulDiv(
            amountFromShares * params.underlyingAssetPrice,
            10 ** params.baseAssetDecimals,
            params.baseAssetPrice * 10 ** params.underlyingAssetDecimals
        );
    }
}
