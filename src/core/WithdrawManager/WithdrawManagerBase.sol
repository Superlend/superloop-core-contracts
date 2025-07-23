// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {WithdrawManagerStorage} from "../lib/WithdrawManagerStorage.sol";

abstract contract WithdrawManagerBase {
    function setInstantWithdrawModule(address instantWithdrawModule_) external onlyVaultAdmin {
        WithdrawManagerStorage.setInstantWithdrawModule(instantWithdrawModule_);
    }

    modifier onlyVaultAdmin() {
        _onlyVaultAdmin();
        _;
    }

    function _onlyVaultAdmin() internal view {
        // todo implement this
    }
}
