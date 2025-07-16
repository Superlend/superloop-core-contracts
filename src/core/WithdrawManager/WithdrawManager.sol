// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {WithdrawManagerStorage} from "./WithdrawManagerStorage.sol";
import {WithdrawManagerValidators} from "./WithdrawManagerValidators.sol";
import {Errors} from "../../common/Errors.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Storages} from "../../common/Storages.sol";

contract WithdrawManager is
    WithdrawManagerStorage,
    Initializable,
    ReentrancyGuardUpgradeable,
    WithdrawManagerValidators
{
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __ReentrancyGuard_init_unchained();
        __SuperloopWithdrawManager_init(_vault);
    }

    function __SuperloopWithdrawManager_init(address _vault) internal onlyInitializing {
        _setVault(_vault);
        _setAsset(IERC4626(_vault).asset());
        _setNextWithdrawRequestId();
    }

    function requestWithdraw(uint256 shares) external override {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        _validateWithdrawRequest($, msg.sender, shares);
        // TODO : Handle fees
        _registerWithdrawRequest($, msg.sender, shares);
    }

    function cancelWithdrawRequest(uint256 id) external override nonReentrant {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        _validateCancelWithdrawRequest($, id);
        _handleCancelWithdrawRequest($, id);
    }

    function resolveWithdrawRequests(uint256 resolvedIdLimit) external override onlyVault {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        _validateResolveWithdrawRequests($, resolvedIdLimit);
        _handleResolveWithdrawRequests($, resolvedIdLimit);
    }

    function withdraw() external override nonReentrant {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        uint256 id = _validateWithdraw($);
        _handleWithdraw($, id);
    }

    function getWithdrawRequestState(uint256 id) public view override returns (DataTypes.WithdrawRequestState) {
        DataTypes.WithdrawRequestData memory withdrawRequest = withdrawRequest(id);
        uint256 resolvedId = resolvedWithdrawRequestId();

        if (withdrawRequest.user == address(0)) {
            return DataTypes.WithdrawRequestState.NOT_EXIST;
        }

        if (withdrawRequest.claimed) {
            return DataTypes.WithdrawRequestState.CLAIMED;
        }

        if (id > resolvedId) return DataTypes.WithdrawRequestState.UNPROCESSED;

        if (withdrawRequest.cancelled) {
            return DataTypes.WithdrawRequestState.CANCELLED;
        }

        return DataTypes.WithdrawRequestState.CLAIMABLE;
    }

    function _registerWithdrawRequest(Storages.WithdrawManagerState storage $, address user, uint256 shares) internal {
        SafeERC20.safeTransferFrom(IERC20(vault()), user, address(this), shares);

        uint256 withdrawReqId = $.nextWithdrawRequestId;

        _setWithdrawRequest(user, shares, 0, withdrawReqId, false, false);
        _setUserWithdrawRequest(user, withdrawReqId);
        _setNextWithdrawRequestId();
    }

    function _handleResolveWithdrawRequests(Storages.WithdrawManagerState storage $, uint256 resolvedIdLimit)
        internal
    {
        // for each of the withdarw request from current resolved window to resolvedIdLimit
        // sum the shares and call the withdraw function on the vault
        uint256 totalShares = 0;
        uint256 totalAssetsDistributed = 0;
        for (uint256 id = $.resolvedWithdrawRequestId + 1; id <= resolvedIdLimit; id++) {
            if ($.withdrawRequest[id].cancelled) continue;
            totalShares += $.withdrawRequest[id].shares;
            uint256 amount = IERC4626(vault()).previewRedeem($.withdrawRequest[id].shares);
            $.withdrawRequest[id].amount = amount;
            totalAssetsDistributed += amount;
        }
        // call the redeem function on the vault
        uint256 totalAssetsRedeemed = IERC4626(vault()).redeem(totalShares, address(this), address(this));

        require(totalAssetsRedeemed == totalAssetsDistributed, Errors.INVALID_ASSETS_DISTRIBUTED);

        _setResolvedWithdrawRequestId(resolvedIdLimit);
    }

    function _handleWithdraw(Storages.WithdrawManagerState storage $, uint256 id) internal {
        DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];
        $.withdrawRequest[id].claimed = true;
        _setUserWithdrawRequest(withdrawRequest.user, 0);

        SafeERC20.safeTransfer(IERC20(asset()), msg.sender, withdrawRequest.amount);
    }

    function _handleCancelWithdrawRequest(Storages.WithdrawManagerState storage $, uint256 id) internal {
        DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];

        $.withdrawRequest[id].cancelled = true;
        _setUserWithdrawRequest(withdrawRequest.user, 0);

        SafeERC20.safeTransfer(IERC20(vault()), withdrawRequest.user, withdrawRequest.shares);
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        require(msg.sender == vault(), Errors.CALLER_NOT_VAULT);
    }
}
