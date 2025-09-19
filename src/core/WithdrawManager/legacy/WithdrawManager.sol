// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "../../../common/Errors.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {WithdrawManagerStorageLegacy} from "../../lib/WithdrawManagerStorageLegacy.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {WithdrawManagerBase} from "./WithdrawManagerBase.sol";

contract WithdrawManager is Initializable, ReentrancyGuardUpgradeable, Context, WithdrawManagerBase {
    event WithdrawRequested(address indexed user, uint256 shares, uint256 requestId);
    event WithdrawRequestCancelled(uint256 indexed requestId, address indexed user);
    event WithdrawRequestsResolved(uint256 resolvedIdLimit);
    event WithdrawRequestResolved(uint256 indexed requestId, address indexed user, uint256 amount);
    event InstantWithdrawExecuted(address indexed user, uint256 shares, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __ReentrancyGuard_init();
        __SuperloopWithdrawManager_init(_vault);
    }

    function __SuperloopWithdrawManager_init(address _vault) internal onlyInitializing {
        WithdrawManagerStorageLegacy.setVault(_vault);
        WithdrawManagerStorageLegacy.setAsset(IERC4626(_vault).asset());
        WithdrawManagerStorageLegacy.setNextWithdrawRequestId();
    }

    function requestWithdraw(uint256 shares) external override {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ = WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        _validateWithdrawRequest($, _msgSender(), shares);
        _registerWithdrawRequest($, _msgSender(), shares);

        emit WithdrawRequested(_msgSender(), shares, $.nextWithdrawRequestId - 1);
    }

    function cancelWithdrawRequest(uint256 id) external override nonReentrant {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ = WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        _validateCancelWithdrawRequest($, id);
        _handleCancelWithdrawRequest($, id);

        emit WithdrawRequestCancelled(id, _msgSender());
    }

    function resolveWithdrawRequests(uint256 resolvedIdLimit) external override onlyVault {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ = WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        _validateResolveWithdrawRequests($, resolvedIdLimit);
        _handleResolveWithdrawRequests($, resolvedIdLimit);

        emit WithdrawRequestsResolved(resolvedIdLimit);
    }

    function withdraw() external override nonReentrant {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ = WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        uint256 id = _validateWithdraw($);
        _handleWithdraw($, id);

        emit WithdrawRequestResolved(id, _msgSender(), $.withdrawRequest[id].amount);
    }

    function withdrawInstant(uint256 shares, bytes memory instantWithdrawData)
        external
        nonReentrant
        returns (uint256)
    {
        require(shares > 0, Errors.INVALID_AMOUNT);

        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ = WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        address instantWithdrawModule = $.instantWithdrawModule;

        if (instantWithdrawModule == address(0)) {
            revert(Errors.INSTANT_WITHDRAW_NOT_ENABLED);
        }

        Address.functionCall(instantWithdrawModule, instantWithdrawData);

        SafeERC20.safeTransferFrom(IERC20($.vault), _msgSender(), address(this), shares);
        uint256 amount = IERC4626($.vault).redeem(shares, _msgSender(), address(this));

        emit InstantWithdrawExecuted(_msgSender(), shares, amount);
        return amount;
    }

    function getWithdrawRequestState(uint256 id) public view override returns (DataTypes.WithdrawRequestStateLegacy) {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ = WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        DataTypes.WithdrawRequestDataLegacy memory _withdrawRequest = $.withdrawRequest[id];
        uint256 resolvedId = $.resolvedWithdrawRequestId;

        if (_withdrawRequest.user == address(0)) {
            return DataTypes.WithdrawRequestStateLegacy.NOT_EXIST;
        }

        if (_withdrawRequest.claimed) {
            return DataTypes.WithdrawRequestStateLegacy.CLAIMED;
        }

        if (_withdrawRequest.cancelled) {
            return DataTypes.WithdrawRequestStateLegacy.CANCELLED;
        }

        if (id > resolvedId) return DataTypes.WithdrawRequestStateLegacy.UNPROCESSED;

        return DataTypes.WithdrawRequestStateLegacy.CLAIMABLE;
    }

    function _validateWithdrawRequest(
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $,
        address user,
        uint256 shares
    ) internal view {
        require(shares > 0, Errors.INVALID_AMOUNT);
        uint256 id = $.userWithdrawRequestId[user];
        DataTypes.WithdrawRequestDataLegacy memory _withdrawRequest = $.withdrawRequest[id];

        // if id != 0, means user has a withdraw request because when cancelled or claimed, the id is set to 0
        if (id != 0) {
            // if user has an active withdraw request, ie. it's not yet resolved or cancelled, revert
            bool isActive = id > $.resolvedWithdrawRequestId && !_withdrawRequest.cancelled;
            if (isActive) revert(Errors.WITHDRAW_REQUEST_ACTIVE);

            // if user has an unclaimed withdraw request, ie. it's resolved but not claimed, revert
            bool isUnclaimed = id <= $.resolvedWithdrawRequestId && !_withdrawRequest.claimed;
            if (isUnclaimed) revert(Errors.WITHDRAW_REQUEST_UNCLAIMED);
        }
    }

    function _validateResolveWithdrawRequests(
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $,
        uint256 resolvedIdLimit
    ) internal view {
        // this id needs to be less than the nextWithdrawRequestId
        require(resolvedIdLimit < $.nextWithdrawRequestId, Errors.INVALID_WITHDRAW_RESOLVED_START_ID_LIMIT);

        // this id needs to be greater than the resolvedWithdrawRequestId
        require(resolvedIdLimit > $.resolvedWithdrawRequestId, Errors.INVALID_WITHDRAW_RESOLVED_END_ID_LIMIT);
    }

    function _validateWithdraw(WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $)
        internal
        view
        virtual
        returns (uint256)
    {
        uint256 id = $.userWithdrawRequestId[_msgSender()];
        require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
        DataTypes.WithdrawRequestDataLegacy memory _withdrawRequest = $.withdrawRequest[id];

        require(
            _withdrawRequest.user == _msgSender() && _withdrawRequest.claimed == false,
            Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED
        );
        require($.resolvedWithdrawRequestId >= id, Errors.WITHDRAW_REQUEST_NOT_RESOLVED);

        return id;
    }

    function _validateCancelWithdrawRequest(WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $, uint256 id)
        internal
        view
    {
        require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
        require(id > $.resolvedWithdrawRequestId, Errors.INVALID_WITHDRAW_REQUEST_STATE);

        DataTypes.WithdrawRequestDataLegacy memory _withdrawRequest = $.withdrawRequest[id];
        require(_withdrawRequest.user == _msgSender(), Errors.CALLER_NOT_WITHDRAW_REQUEST_OWNER);
    }

    function _registerWithdrawRequest(
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $,
        address user,
        uint256 shares
    ) internal {
        SafeERC20.safeTransferFrom(IERC20($.vault), user, address(this), shares);

        uint256 withdrawReqId = $.nextWithdrawRequestId;

        WithdrawManagerStorageLegacy.setWithdrawRequest(user, shares, 0, withdrawReqId, false, false);
        WithdrawManagerStorageLegacy.setUserWithdrawRequest(user, withdrawReqId);
        WithdrawManagerStorageLegacy.setNextWithdrawRequestId();
    }

    function _handleResolveWithdrawRequests(
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $,
        uint256 resolvedIdLimit
    ) internal {
        // for each of the withdarw request from current resolved window to resolvedIdLimit
        // sum the shares and call the withdraw function on the vault
        uint256 totalShares = 0;
        uint256 totalAssetsDistributed = 0;
        for (uint256 id = $.resolvedWithdrawRequestId + 1; id <= resolvedIdLimit; id++) {
            if ($.withdrawRequest[id].cancelled) continue;
            totalShares += $.withdrawRequest[id].shares;
            uint256 amount = IERC4626($.vault).previewRedeem($.withdrawRequest[id].shares);
            $.withdrawRequest[id].amount = amount;
            totalAssetsDistributed += amount;
        }
        // call the redeem function on the vault
        uint256 totalAssetsRedeemed = IERC4626($.vault).redeem(totalShares, address(this), address(this));

        require(totalAssetsRedeemed >= totalAssetsDistributed, Errors.INVALID_ASSETS_DISTRIBUTED);

        // if redeemed more than distributed, return the difference to the vault
        if (totalAssetsRedeemed > totalAssetsDistributed) {
            SafeERC20.safeTransfer(IERC20($.asset), _msgSender(), totalAssetsRedeemed - totalAssetsDistributed);
        }

        WithdrawManagerStorageLegacy.setResolvedWithdrawRequestId(resolvedIdLimit);
    }

    function _handleWithdraw(WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $, uint256 id) internal {
        DataTypes.WithdrawRequestDataLegacy memory _withdrawRequest = $.withdrawRequest[id];
        $.withdrawRequest[id].claimed = true;
        WithdrawManagerStorageLegacy.setUserWithdrawRequest(_withdrawRequest.user, 0);

        SafeERC20.safeTransfer(IERC20($.asset), _msgSender(), _withdrawRequest.amount);
    }

    function _handleCancelWithdrawRequest(WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $, uint256 id) internal {
        DataTypes.WithdrawRequestDataLegacy memory _withdrawRequest = $.withdrawRequest[id];

        $.withdrawRequest[id].cancelled = true;
        WithdrawManagerStorageLegacy.setUserWithdrawRequest(_withdrawRequest.user, 0);

        SafeERC20.safeTransfer(IERC20($.vault), _withdrawRequest.user, _withdrawRequest.shares);
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ = WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        require(_msgSender() == $.vault, Errors.CALLER_NOT_VAULT);
    }
}
