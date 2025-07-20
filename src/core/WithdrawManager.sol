// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "../common/Errors.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {WithdrawManagerStorage} from "./lib/WithdrawManagerStorage.sol";
import {IWithdrawManager} from "../interfaces/IWithdrawManager.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";

contract WithdrawManager is Initializable, ReentrancyGuardUpgradeable, Context, IWithdrawManager {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __ReentrancyGuard_init();
        __SuperloopWithdrawManager_init(_vault);
    }

    function __SuperloopWithdrawManager_init(address _vault) internal onlyInitializing {
        WithdrawManagerStorage.setVault(_vault);
        WithdrawManagerStorage.setAsset(IERC4626(_vault).asset());
        WithdrawManagerStorage.setNextWithdrawRequestId();
    }

    function requestWithdraw(uint256 shares) external override {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        _validateWithdrawRequest($, _msgSender(), shares);
        _registerWithdrawRequest($, _msgSender(), shares);
    }

    function cancelWithdrawRequest(uint256 id) external override nonReentrant {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        _validateCancelWithdrawRequest($, id);
        _handleCancelWithdrawRequest($, id);
    }

    function resolveWithdrawRequests(uint256 resolvedIdLimit) external override onlyVault {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        _validateResolveWithdrawRequests($, resolvedIdLimit);
        _handleResolveWithdrawRequests($, resolvedIdLimit);
    }

    function withdraw() external override nonReentrant {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        uint256 id = _validateWithdraw($);
        _handleWithdraw($, id);
    }

    function getWithdrawRequestState(uint256 id) public view override returns (DataTypes.WithdrawRequestState) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        DataTypes.WithdrawRequestData memory _withdrawRequest = $.withdrawRequest[id];
        uint256 resolvedId = $.resolvedWithdrawRequestId;

        if (_withdrawRequest.user == address(0)) {
            return DataTypes.WithdrawRequestState.NOT_EXIST;
        }

        if (_withdrawRequest.claimed) {
            return DataTypes.WithdrawRequestState.CLAIMED;
        }

        if (id > resolvedId) return DataTypes.WithdrawRequestState.UNPROCESSED;

        if (_withdrawRequest.cancelled) {
            return DataTypes.WithdrawRequestState.CANCELLED;
        }

        return DataTypes.WithdrawRequestState.CLAIMABLE;
    }

    function vault() public view override returns (address) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.vault;
    }

    function asset() public view override returns (address) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.asset;
    }

    function nextWithdrawRequestId() public view override returns (uint256) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.nextWithdrawRequestId;
    }

    function resolvedWithdrawRequestId() public view override returns (uint256) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.resolvedWithdrawRequestId;
    }

    function withdrawRequest(uint256 id) public view override returns (DataTypes.WithdrawRequestData memory) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.withdrawRequest[id];
    }

    function withdrawRequests(uint256[] memory ids)
        public
        view
        override
        returns (DataTypes.WithdrawRequestData[] memory)
    {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        DataTypes.WithdrawRequestData[] memory _withdrawRequests = new DataTypes.WithdrawRequestData[](ids.length);
        uint256 length = ids.length;
        for (uint256 i; i < length;) {
            _withdrawRequests[i] = $.withdrawRequest[ids[i]];
            unchecked {
                ++i;
            }
        }

        return _withdrawRequests;
    }

    function userWithdrawRequestId(address user) public view override returns (uint256) {
        user = user == address(0) ? msg.sender : user;
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();

        return $.userWithdrawRequestId[user];
    }

    function _validateWithdrawRequest(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        address user,
        uint256 shares
    ) internal view {
        require(shares > 0, Errors.INVALID_AMOUNT);
        uint256 id = $.userWithdrawRequestId[user];
        DataTypes.WithdrawRequestData memory _withdrawRequest = $.withdrawRequest[id];

        if (_withdrawRequest.user == user && id <= $.resolvedWithdrawRequestId && !_withdrawRequest.claimed) {
            revert(Errors.WITHDRAW_REQUEST_ACTIVE);
        }
    }

    function _validateResolveWithdrawRequests(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        uint256 resolvedIdLimit
    ) internal view {
        // this id needs to be less than the nextWithdrawRequestId
        require(resolvedIdLimit < $.nextWithdrawRequestId, Errors.INVALID_WITHDRAW_RESOLVED_START_ID_LIMIT);

        // this id needs to be greater than the resolvedWithdrawRequestId
        require(resolvedIdLimit > $.resolvedWithdrawRequestId, Errors.INVALID_WITHDRAW_RESOLVED_END_ID_LIMIT);
    }

    function _validateWithdraw(WithdrawManagerStorage.WithdrawManagerState storage $)
        internal
        view
        virtual
        returns (uint256)
    {
        uint256 id = $.userWithdrawRequestId[_msgSender()];
        require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
        DataTypes.WithdrawRequestData memory _withdrawRequest = $.withdrawRequest[id];

        require(
            _withdrawRequest.user == _msgSender() && _withdrawRequest.claimed == false,
            Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED
        );
        require($.resolvedWithdrawRequestId >= id, Errors.WITHDRAW_REQUEST_NOT_RESOLVED);

        return id;
    }

    function _validateCancelWithdrawRequest(WithdrawManagerStorage.WithdrawManagerState storage $, uint256 id)
        internal
        view
    {
        require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
        require(id > $.resolvedWithdrawRequestId, Errors.INVALID_WITHDRAW_REQUEST_STATE);

        DataTypes.WithdrawRequestData memory _withdrawRequest = $.withdrawRequest[id];
        require(_withdrawRequest.user == _msgSender(), Errors.CALLER_NOT_WITHDRAW_REQUEST_OWNER);
        require(!_withdrawRequest.claimed, Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED);
    }

    function _registerWithdrawRequest(
        WithdrawManagerStorage.WithdrawManagerState storage $,
        address user,
        uint256 shares
    ) internal {
        SafeERC20.safeTransferFrom(IERC20($.vault), user, address(this), shares);

        uint256 withdrawReqId = $.nextWithdrawRequestId;

        WithdrawManagerStorage.setWithdrawRequest(user, shares, 0, withdrawReqId, false, false);
        WithdrawManagerStorage.setUserWithdrawRequest(user, withdrawReqId);
        WithdrawManagerStorage.setNextWithdrawRequestId();
    }

    function _handleResolveWithdrawRequests(
        WithdrawManagerStorage.WithdrawManagerState storage $,
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

        require(totalAssetsRedeemed == totalAssetsDistributed, Errors.INVALID_ASSETS_DISTRIBUTED);

        WithdrawManagerStorage.setResolvedWithdrawRequestId(resolvedIdLimit);
    }

    function _handleWithdraw(WithdrawManagerStorage.WithdrawManagerState storage $, uint256 id) internal {
        DataTypes.WithdrawRequestData memory _withdrawRequest = $.withdrawRequest[id];
        $.withdrawRequest[id].claimed = true;
        WithdrawManagerStorage.setUserWithdrawRequest(_withdrawRequest.user, 0);

        SafeERC20.safeTransfer(IERC20($.asset), _msgSender(), _withdrawRequest.amount);
    }

    function _handleCancelWithdrawRequest(WithdrawManagerStorage.WithdrawManagerState storage $, uint256 id) internal {
        DataTypes.WithdrawRequestData memory _withdrawRequest = $.withdrawRequest[id];

        $.withdrawRequest[id].cancelled = true;
        WithdrawManagerStorage.setUserWithdrawRequest(_withdrawRequest.user, 0);

        SafeERC20.safeTransfer(IERC20($.vault), _withdrawRequest.user, _withdrawRequest.shares);
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        require(_msgSender() == $.vault, Errors.CALLER_NOT_VAULT);
    }
}
