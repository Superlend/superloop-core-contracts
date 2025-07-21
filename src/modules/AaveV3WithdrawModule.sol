// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";

contract AaveV3WithdrawModule is AaveV3ActionModule {
    constructor(address poolAddressesProvider_) AaveV3ActionModule(poolAddressesProvider_) {}

    function execute(DataTypes.AaveV3ActionParams memory params) external override onlyExecutionContext {
        // get the pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // withdraw the asset
        pool.withdraw(params.asset, params.amount, address(this));
    }
}
