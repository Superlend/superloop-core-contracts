// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AaveV3SupplyModule
 * @author Superlend
 * @notice Module for executing Aave V3 supply operations
 * @dev Extends AaveV3ActionModule to provide asset supply functionality
 */
contract AaveV3SupplyModule is AaveV3ActionModule {
    /**
     * @notice Emitted when an asset is supplied to Aave V3
     * @param asset The address of the supplied asset
     * @param amount The amount of the asset supplied
     * @param supplier The address of the supplier
     */
    event AssetSupplied(address indexed asset, uint256 amount, address indexed supplier);

    /**
     * @notice Constructor to initialize the Aave V3 supply module
     * @param poolAddressesProvider_ The address of the Aave V3 pool addresses provider
     */
    constructor(address poolAddressesProvider_) AaveV3ActionModule(poolAddressesProvider_) {}

    /**
     * @notice Executes a supply operation on Aave V3
     * @param params The parameters for the supply operation
     */
    function execute(DataTypes.AaveV3ActionParams memory params) external override onlyExecutionContext {
        // approve the asset
        uint256 amount =
            params.amount == type(uint256).max ? IERC20(params.asset).balanceOf(address(this)) : params.amount;

        if (amount != 0) {
            // get the pool
            IPool pool = IPool(poolAddressesProvider.getPool());

            SafeERC20.forceApprove(IERC20(params.asset), address(pool), amount);

            // supply the asset
            pool.supply(params.asset, amount, address(this), 0);

            emit AssetSupplied(params.asset, amount, address(this));
        }
    }
}
