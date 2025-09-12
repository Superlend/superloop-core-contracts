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
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        return $.depositRequest[id];
    }

    function depositRequests(uint256[] memory ids) public view returns (DataTypes.DepositRequestData[] memory) {
        DepositManagerStorage.DepositManagerState storage $ = DepositManagerStorage.getDepositManagerStorage();
        DataTypes.DepositRequestData[] memory _depositRequests = new DataTypes.DepositRequestData[](ids.length);
        uint256 length = ids.length;
        for (uint256 i; i < length;) {
            _depositRequests[i] = $.depositRequest[ids[i]];
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
        return ($.depositRequest[id], id);
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
}
