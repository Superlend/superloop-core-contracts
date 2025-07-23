// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";

contract AaveV3BorrowModule is AaveV3ActionModule {
    event AssetBorrowed(address indexed asset, uint256 amount, address indexed borrower);

    constructor(address poolAddressesProvider_) AaveV3ActionModule(poolAddressesProvider_) {}

    function execute(DataTypes.AaveV3ActionParams memory params) external override onlyExecutionContext {
        // get the pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // borrow the asset
        pool.borrow(params.asset, params.amount, INTEREST_RATE_MODE, 0, address(this));

        emit AssetBorrowed(params.asset, params.amount, address(this));
    }
}
