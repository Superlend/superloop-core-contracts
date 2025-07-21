// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveV3SupplyModule is AaveV3ActionModule {
    constructor(address poolAddressesProvider_) AaveV3ActionModule(poolAddressesProvider_) {}

    function execute(DataTypes.AaveV3ActionParams memory params) external override onlyExecutionContext {
        // get the pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // approve the asset
        SafeERC20.forceApprove(IERC20(params.asset), address(pool), params.amount);

        // supply the asset
        pool.supply(params.asset, params.amount, address(this), 0);
    }
}
