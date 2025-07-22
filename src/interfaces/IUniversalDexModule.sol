// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

interface IUniversalDexModule {
    function execute(DataTypes.ExecuteSwapParams memory params) external returns (uint256);

    function executeAndExit(DataTypes.ExecuteSwapParams memory params, address to) external returns (uint256);
}
