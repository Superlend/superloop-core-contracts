// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

interface IAaveV3ActionModule {
    function execute(DataTypes.AaveV3ActionParams memory params) external;
}
