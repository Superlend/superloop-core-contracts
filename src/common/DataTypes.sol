// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library DataTypes {
    struct ModuleData {
        string moduleName;
        address moduleAddress;
    }

    struct WithdrawRequestData {
        uint256 shares;
        address user;
    }
}
