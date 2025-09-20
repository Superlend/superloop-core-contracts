// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {WithdrawManagerStorageLegacy} from "../../lib/WithdrawManagerStorageLegacy.sol";
import {ISuperloop} from "../../../interfaces/ISuperloop.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {Errors} from "../../../common/Errors.sol";
import {IWithdrawManager} from "../../../interfaces/IWithdrawManager.sol";

abstract contract WithdrawManagerBase is Context, IWithdrawManager {
    event InstantWithdrawModuleUpdated(address indexed oldModule, address indexed newModule);

    function setInstantWithdrawModule(address instantWithdrawModule_) external onlyVaultAdmin {
        address oldModule = WithdrawManagerStorageLegacy.getWithdrawManagerStorage().instantWithdrawModule;
        WithdrawManagerStorageLegacy.setInstantWithdrawModule(instantWithdrawModule_);
        emit InstantWithdrawModuleUpdated(oldModule, instantWithdrawModule_);
    }

    function vault() public view override returns (address) {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ =
            WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        return $.vault;
    }

    function asset() public view override returns (address) {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ =
            WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        return $.asset;
    }

    function nextWithdrawRequestId() public view override returns (uint256) {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ =
            WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        return $.nextWithdrawRequestId;
    }

    function resolvedWithdrawRequestId() public view override returns (uint256) {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ =
            WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        return $.resolvedWithdrawRequestId;
    }

    function withdrawRequest(uint256 id) public view override returns (DataTypes.WithdrawRequestDataLegacy memory) {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ =
            WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        return $.withdrawRequest[id];
    }

    function withdrawRequests(uint256[] memory ids)
        public
        view
        override
        returns (DataTypes.WithdrawRequestDataLegacy[] memory)
    {
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ =
            WithdrawManagerStorageLegacy.getWithdrawManagerStorage();
        DataTypes.WithdrawRequestDataLegacy[] memory _withdrawRequests =
            new DataTypes.WithdrawRequestDataLegacy[](ids.length);
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
        WithdrawManagerStorageLegacy.WithdrawManagerStateLegacy storage $ =
            WithdrawManagerStorageLegacy.getWithdrawManagerStorage();

        return $.userWithdrawRequestId[user];
    }

    modifier onlyVaultAdmin() {
        _onlyVaultAdmin();
        _;
    }

    function _onlyVaultAdmin() internal view {
        ISuperloop superloop = ISuperloop(WithdrawManagerStorageLegacy.getWithdrawManagerStorage().vault);
        require(superloop.vaultAdmin() == _msgSender(), Errors.CALLER_NOT_VAULT_ADMIN);
    }
}
