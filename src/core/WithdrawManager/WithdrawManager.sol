// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {WithdrawManagerStorage} from "./WithdrawManagerStorage.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

contract WithdrawManager is
    WithdrawManagerStorage,
    Initializable,
    ReentrancyGuardUpgradeable
{
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __ReentrancyGuard_init_unchained();
        __SuperloopWithdrawManager_init(_vault);
    }

    function __SuperloopWithdrawManager_init(
        address _vault
    ) internal onlyInitializing {
        _setVault(_vault);
    }

    function requestWithdraw(uint256 shares) external {
        // make sure the msg.sender has enough shares
        // make sure the user does not have any withdraw request active
        // TODO: handle fee ??
        // register this withdraw request
    }
}
