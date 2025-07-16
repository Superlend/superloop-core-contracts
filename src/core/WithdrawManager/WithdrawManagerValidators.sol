// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {Storages} from "../../common/Storages.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";

abstract contract WithdrawManagerValidators is Context {
    function _validateWithdrawRequest(Storages.WithdrawManagerState storage $, address user, uint256 shares)
        internal
        view
    {
        require(shares > 0, Errors.INVALID_AMOUNT);
        uint256 id = $.userWithdrawRequestId[user];
        DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];

        if (withdrawRequest.user == user && id <= $.resolvedWithdrawRequestId && !withdrawRequest.claimed) {
            revert(Errors.WITHDRAW_REQUEST_ACTIVE);
        }
    }

    function _validateResolveWithdrawRequests(Storages.WithdrawManagerState storage $, uint256 resolvedIdLimit)
        internal
        view
    {
        // this id needs to be less than the nextWithdrawRequestId
        require(resolvedIdLimit < $.nextWithdrawRequestId, Errors.INVALID_WITHDRAW_RESOLVED_START_ID_LIMIT);

        // this id needs to be greater than the resolvedWithdrawRequestId
        require(resolvedIdLimit > $.resolvedWithdrawRequestId, Errors.INVALID_WITHDRAW_RESOLVED_END_ID_LIMIT);
    }

    function _validateWithdraw(Storages.WithdrawManagerState storage $) internal view returns (uint256) {
        uint256 id = $.userWithdrawRequestId[_msgSender()];
        require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
        DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];

        require(
            withdrawRequest.user == _msgSender() && withdrawRequest.claimed == false,
            Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED
        );
        require($.resolvedWithdrawRequestId >= id, Errors.WITHDRAW_REQUEST_NOT_RESOLVED);

        return id;
    }

    function _validateCancelWithdrawRequest(Storages.WithdrawManagerState storage $, uint256 id) internal view {
        require(id > 0, Errors.WITHDRAW_REQUEST_NOT_FOUND);
        require(id > $.resolvedWithdrawRequestId, Errors.INVALID_WITHDRAW_REQUEST_STATE);

        DataTypes.WithdrawRequestData memory withdrawRequest = $.withdrawRequest[id];
        require(withdrawRequest.user == _msgSender(), Errors.CALLER_NOT_WITHDRAW_REQUEST_OWNER);
        require(!withdrawRequest.claimed, Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED);
    }
}
