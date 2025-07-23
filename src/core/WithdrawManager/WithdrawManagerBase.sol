// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {WithdrawManagerStorage} from "../lib/WithdrawManagerStorage.sol";
import {ISuperloop} from "../../interfaces/ISuperloop.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";
import {IWithdrawManager} from "../../interfaces/IWithdrawManager.sol";

abstract contract WithdrawManagerBase is Context, IWithdrawManager {
    function setInstantWithdrawModule(address instantWithdrawModule_) external onlyVaultAdmin {
        WithdrawManagerStorage.setInstantWithdrawModule(instantWithdrawModule_);
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

    modifier onlyVaultAdmin() {
        _onlyVaultAdmin();
        _;
    }

    function _onlyVaultAdmin() internal view {
        ISuperloop superloop = ISuperloop(WithdrawManagerStorage.getWithdrawManagerStorage().vault);
        require(superloop.vaultAdmin() == _msgSender(), Errors.CALLER_NOT_VAULT_ADMIN);
    }
}
