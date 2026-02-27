// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";

/**
 * @title AaveV3WithdrawModule
 * @author Superlend
 * @notice Module for executing Aave V3 withdraw operations
 * @dev Extends AaveV3ActionModule to provide asset withdrawal functionality
 */
contract AaveV3WithdrawModule is AaveV3ActionModule {
    event AssetWithdrawn(address indexed asset, uint256 amount, address indexed withdrawer);

    constructor(address poolAddressesProvider_) AaveV3ActionModule(poolAddressesProvider_) {}

    function execute(DataTypes.AaveV3ActionParams memory params) external override onlyExecutionContext {
        // get the pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // withdraw the asset
        pool.withdraw(params.asset, params.amount, address(this));

        emit AssetWithdrawn(params.asset, params.amount, address(this));
    }
}
