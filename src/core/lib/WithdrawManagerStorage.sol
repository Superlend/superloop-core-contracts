// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";

library WithdrawManagerStorage {
    struct WithdrawManagerState {
        address vault;
        address asset;
        uint8 vaultDecimalOffset;
        mapping(DataTypes.WithdrawRequestType => DataTypes.WithdrawQueue) queues;
    }

    /**
     * @dev Storage location constant for the withdraw manager storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.storage.WithdrawManager")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant WithdrawManagerStorageLocation =
        0x423bea3933e6a497b6fb476970c32da2d847e7ebc3511b83b7ac2aafc89c0d00;

    function getWithdrawManagerStorage() internal pure returns (WithdrawManagerState storage $) {
        assembly {
            $.slot := WithdrawManagerStorageLocation
        }
    }

    function setWithdrawRequest(
        DataTypes.WithdrawRequestType requestType,
        uint256 id,
        uint256 shares,
        uint256 sharesProcessed,
        uint256 amountClaimable,
        uint256 amountClaimed,
        address user,
        DataTypes.RequestProcessingState state
    ) internal {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();

        $.queues[requestType].withdrawRequest[id] =
            DataTypes.WithdrawRequestData(shares, sharesProcessed, amountClaimable, amountClaimed, user, state);
    }

    function setNextWithdrawRequestId(DataTypes.WithdrawRequestType requestType) internal {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();
        $.queues[requestType].nextWithdrawRequestId = $.queues[requestType].nextWithdrawRequestId + 1;
    }

    function setUserWithdrawRequest(DataTypes.WithdrawRequestType requestType, address user, uint256 id) internal {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();
        $.queues[requestType].userWithdrawRequestId[user] = id;
    }

    function setResolutionIdPointer(DataTypes.WithdrawRequestType requestType, uint256 resolutionIdPointer) internal {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();
        $.queues[requestType].resolutionIdPointer = resolutionIdPointer;
    }

    function setTotalPendingWithdraws(DataTypes.WithdrawRequestType requestType, uint256 totalPendingWithdraws)
        internal
    {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();
        $.queues[requestType].totalPendingWithdraws = totalPendingWithdraws;
    }

    function setVault(address __vault) internal {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();
        $.vault = __vault;
    }

    function setAsset(address __asset) internal {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();
        $.asset = __asset;
    }

    function setDecimalOffset(uint8 __decimalOffset) internal {
        WithdrawManagerState storage $ = getWithdrawManagerStorage();
        $.vaultDecimalOffset = __decimalOffset;
    }
}
