// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
import {DataTypes} from "../../common/DataTypes.sol";
import {Storages} from "../../common/Storages.sol";
import {WithdrawManagerBase} from "./WithdrawManagerBase.sol";
import {IWithdrawManager} from "../../interfaces/IWithdrawManager.sol";

abstract contract WithdrawManagerStorage is
    IWithdrawManager,
    WithdrawManagerBase
{
    // Setters

    function _addWithdrawRequest(
        address user,
        uint256 shares,
        uint256 id
    ) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();

        $.withdrawRequest[id] = DataTypes.WithdrawRequestData(shares, user);
        $.userWithdrawRequestId[user] = id;

        emit WithdrawRequest(user, shares, id);
    }

    function _setNextWithdrawRequestId(uint256 id) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.nextWithdrawRequestId = id;
    }

    function _setTotalWithdrawableShares(uint256 shares) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.totalWithdrawableShares = shares;
    }

    function _setUserWithdrawRequest(address user, uint256 id) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.userWithdrawRequestId[user] = id;
    }

    function _setWithdrawWindowStartId(uint256 id) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.withdrawWindowStartId = id;
    }

    function _setWithdrawWindowEndId(uint256 id) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.withdrawWindowEndId = id;
    }

    function _setVault(address __vault) internal {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        $.vault = __vault;
    }

    // Getters

    function nextWithdrawRequestId() public view returns (uint256) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.nextWithdrawRequestId;
    }

    function totalWithdrawableShares() public view returns (uint256) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.totalWithdrawableShares;
    }

    function userWithdrawRequestId(address user) public view returns (uint256) {
        user = user == address(0) ? msg.sender : user;
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();

        return $.userWithdrawRequestId[user];
    }

    function withdrawRequest(
        uint256 id
    ) public view returns (DataTypes.WithdrawRequestData memory) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.withdrawRequest[id];
    }

    function withdrawWindow() public view returns (uint256, uint256) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return ($.withdrawWindowStartId, $.withdrawWindowEndId);
    }

    function vault() public view returns (address) {
        Storages.WithdrawManagerState storage $ = _getWithdrawManagerStorage();
        return $.vault;
    }
}
