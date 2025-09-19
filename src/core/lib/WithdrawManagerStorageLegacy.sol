// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";

library WithdrawManagerStorageLegacy {
    struct WithdrawManagerStateLegacy {
        address vault;
        address asset;
        uint256 nextWithdrawRequestId;
        uint256 resolvedWithdrawRequestId;
        address instantWithdrawModule;
        mapping(uint256 => DataTypes.WithdrawRequestDataLegacy) withdrawRequest;
        mapping(address => uint256) userWithdrawRequestId;
    }

    /**
     * @dev Storage location constant for the withdraw manager storage.
     * Computed using: keccak256(abi.encode(uint256(keccak256("superloop.storage.WithdrawManager")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant WithdrawManagerStorageLocation =
        0x423bea3933e6a497b6fb476970c32da2d847e7ebc3511b83b7ac2aafc89c0d00;

    function getWithdrawManagerStorage() internal pure returns (WithdrawManagerStateLegacy storage $) {
        assembly {
            $.slot := WithdrawManagerStorageLocation
        }
    }

    function setWithdrawRequest(address user, uint256 shares, uint256 amount, uint256 id, bool claimed, bool cancelled)
        internal
    {
        WithdrawManagerStateLegacy storage $ = getWithdrawManagerStorage();

        $.withdrawRequest[id] = DataTypes.WithdrawRequestDataLegacy(shares, amount, user, claimed, cancelled);
    }

    function setNextWithdrawRequestId() internal {
        WithdrawManagerStateLegacy storage $ = getWithdrawManagerStorage();
        $.nextWithdrawRequestId = $.nextWithdrawRequestId + 1;
    }

    function setUserWithdrawRequest(address user, uint256 id) internal {
        WithdrawManagerStateLegacy storage $ = getWithdrawManagerStorage();
        $.userWithdrawRequestId[user] = id;
    }

    function setResolvedWithdrawRequestId(uint256 id) internal {
        WithdrawManagerStateLegacy storage $ = getWithdrawManagerStorage();
        $.resolvedWithdrawRequestId = id;
    }

    function setVault(address __vault) internal {
        WithdrawManagerStateLegacy storage $ = getWithdrawManagerStorage();
        $.vault = __vault;
    }

    function setAsset(address __asset) internal {
        WithdrawManagerStateLegacy storage $ = getWithdrawManagerStorage();
        $.asset = __asset;
    }

    function setInstantWithdrawModule(address __instantWithdrawModule) internal {
        WithdrawManagerStateLegacy storage $ = getWithdrawManagerStorage();
        $.instantWithdrawModule = __instantWithdrawModule;
    }
}
