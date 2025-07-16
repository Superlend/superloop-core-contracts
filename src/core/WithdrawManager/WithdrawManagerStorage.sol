// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";
import {Storages} from "../../common/Storages.sol";
import {WithdrawManagerBase} from "./WithdrawManagerBase.sol";
import {IWithdrawManager} from "../../interfaces/IWithdrawManager.sol";

abstract contract WithdrawManagerStorage is IWithdrawManager, WithdrawManagerBase {
    function _setWithdrawRequest(address user, uint256 shares, uint256 amount, uint256 id, bool claimed, bool cancelled)
        internal
    {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();

        $.withdrawRequest[id] = DataTypes.WithdrawRequestData(shares, amount, user, claimed, cancelled);

        emit WithdrawRequest(user, shares, amount, id);
    }

    function _setNextWithdrawRequestId() internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.nextWithdrawRequestId = $.nextWithdrawRequestId + 1;
    }

    function _setUserWithdrawRequest(address user, uint256 id) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.userWithdrawRequestId[user] = id;
    }

    function _setResolvedWithdrawRequestId(uint256 id) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.resolvedWithdrawRequestId = id;
    }

    function _setVault(address __vault) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.vault = __vault;
    }

    function _setAsset(address __asset) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.asset = __asset;
    }

    function vault() public view override returns (address) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.vault;
    }

    function asset() public view override returns (address) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.asset;
    }

    function nextWithdrawRequestId() public view override returns (uint256) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.nextWithdrawRequestId;
    }

    function resolvedWithdrawRequestId() public view override returns (uint256) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.resolvedWithdrawRequestId;
    }

    function withdrawRequest(uint256 id) public view override returns (DataTypes.WithdrawRequestData memory) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.withdrawRequest[id];
    }

    function userWithdrawRequestId(address user) public view override returns (uint256) {
        user = user == address(0) ? msg.sender : user;
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();

        return $.userWithdrawRequestId[user];
    }
}
