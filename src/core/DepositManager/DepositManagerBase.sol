// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DepositManagerStorage} from "../lib/DepositManagerStorage.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../../common/DataTypes.sol";

abstract contract DepositManagerBase is Context {
    function vault() public view returns (address) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return $.vault;
    }

    function asset() public view returns (address) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return $.asset;
    }

    function nextDepositRequestId() public view returns (uint256) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return $.nextDepositRequestId;
    }

    function depositRequest(uint256 id) public view returns (DataTypes.DepositRequestData memory) {
        return _depositRequest(id);
    }

    function depositRequests(uint256[] memory ids) public view returns (DataTypes.DepositRequestData[] memory) {
        DataTypes.DepositRequestData[] memory _depositRequests = new DataTypes.DepositRequestData[](ids.length);
        uint256 length = ids.length;
        for (uint256 i; i < length;) {
            _depositRequests[i] = _depositRequest(ids[i]);
            unchecked {
                ++i;
            }
        }
        return _depositRequests;
    }

    function userDepositRequest(address user) public view returns (DataTypes.DepositRequestData memory, uint256) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        user = user == address(0) ? _msgSender() : user;
        uint256 id = $.userDepositRequestId[user];
        return (_depositRequest(id), id);
    }

    function totalPendingDeposits() public view returns (uint256) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return $.totalPendingDeposits;
    }

    function resolutionIdPointer() public view returns (uint256) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return $.resolutionIdPointer;
    }

    function vaultDecimalOffset() public view returns (uint8) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return $.vaultDecimalOffset;
    }

    function _depositRequest(uint256 id) internal view returns (DataTypes.DepositRequestData memory) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        DataTypes.DepositRequestData memory __depositRequest = $.depositRequest[id];

        if (id >= $.resolutionIdPointer) {
            return __depositRequest;
        } else {
            if (
                __depositRequest.state == DataTypes.RequestProcessingState.CANCELLED
                    || __depositRequest.state == DataTypes.RequestProcessingState.PARTIALLY_CANCELLED
            ) {
                return __depositRequest;
            } else {
                __depositRequest.state = DataTypes.RequestProcessingState.FULLY_PROCESSED;
                __depositRequest.amountProcessed = __depositRequest.amount;
                return __depositRequest;
            }
        }
    }

    struct DepositManagerCache {
        address vault;
        address asset;
        uint8 vaultDecimalOffset;
        uint256 nextDepositRequestId;
        uint256 resolutionIdPointer;
        uint256 totalPendingDeposits;
    }

    function _createDepositManagerCache()
        internal
        view
        returns (DepositManagerCache memory, DepositManagerStorage.DepositManagerState storage)
    {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return (
            DepositManagerCache({
                vault: $.vault,
                asset: $.asset,
                vaultDecimalOffset: $.vaultDecimalOffset,
                nextDepositRequestId: $.nextDepositRequestId,
                resolutionIdPointer: $.resolutionIdPointer,
                totalPendingDeposits: $.totalPendingDeposits
            }),
            $
        );
    }
}
