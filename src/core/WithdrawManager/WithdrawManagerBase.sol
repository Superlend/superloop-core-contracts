// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {WithdrawManagerStorage} from "../lib/WithdrawManagerStorage.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../../common/DataTypes.sol";

abstract contract WithdrawManagerBase is Context {
    function vault() public view returns (address) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.vault;
    }

    function asset() public view returns (address) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.asset;
    }

    function nextWithdrawRequestId(DataTypes.WithdrawRequestType requestType) public view returns (uint256) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.queues[requestType].nextWithdrawRequestId;
    }

    function withdrawRequest(uint256 id, DataTypes.WithdrawRequestType requestType)
        public
        view
        returns (DataTypes.WithdrawRequestData memory)
    {
        return _withdrawRequest(id, requestType);
    }

    function withdrawRequests(uint256[] memory ids, DataTypes.WithdrawRequestType requestType)
        public
        view
        returns (DataTypes.WithdrawRequestData[] memory)
    {
        DataTypes.WithdrawRequestData[] memory _withdrawRequests = new DataTypes.WithdrawRequestData[](ids.length);
        uint256 length = ids.length;
        for (uint256 i; i < length;) {
            _withdrawRequests[i] = _withdrawRequest(ids[i], requestType);
            unchecked {
                ++i;
            }
        }
        return _withdrawRequests;
    }

    function userWithdrawRequestId(address user, DataTypes.WithdrawRequestType requestType)
        public
        view
        returns (uint256)
    {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.queues[requestType].userWithdrawRequestId[user];
    }

    function totalPendingWithdraws(DataTypes.WithdrawRequestType requestType) public view returns (uint256) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.queues[requestType].totalPendingWithdraws;
    }

    function resolutionIdPointer(DataTypes.WithdrawRequestType requestType) public view returns (uint256) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.queues[requestType].resolutionIdPointer;
    }

    function vaultDecimalOffset() public view returns (uint8) {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        return $.vaultDecimalOffset;
    }

    function _withdrawRequest(uint256 id, DataTypes.WithdrawRequestType requestType)
        internal
        view
        returns (DataTypes.WithdrawRequestData memory)
    {
        WithdrawManagerStorage.WithdrawManagerState storage $ = WithdrawManagerStorage.getWithdrawManagerStorage();
        DataTypes.WithdrawRequestData memory __withdrawRequest = $.queues[requestType].withdrawRequest[id];
        uint256 _resolutionIdPointer = $.queues[requestType].resolutionIdPointer;

        if (id >= _resolutionIdPointer) {
            return __withdrawRequest;
        } else if (
            __withdrawRequest.state == DataTypes.RequestProcessingState.CANCELLED
                || __withdrawRequest.state == DataTypes.RequestProcessingState.PARTIALLY_CANCELLED
        ) {
            return __withdrawRequest;
        } else {
            __withdrawRequest.state = DataTypes.RequestProcessingState.FULLY_PROCESSED;
            __withdrawRequest.sharesProcessed = __withdrawRequest.shares;
            return __withdrawRequest;
        }
    }
}
