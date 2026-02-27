// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AaveV3RepayModule
 * @author Superlend
 * @notice Module for executing Aave V3 repay operations
 * @dev Extends AaveV3ActionModule to provide debt repayment functionality
 */
contract AaveV3RepayModule is AaveV3ActionModule {
    event AssetRepaid(address indexed asset, uint256 amount, address indexed repayer);

    constructor(address poolAddressesProvider_) AaveV3ActionModule(poolAddressesProvider_) {}

    function execute(DataTypes.AaveV3ActionParams memory params) external override onlyExecutionContext {
        // get the pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // approve the asset
        SafeERC20.forceApprove(IERC20(params.asset), address(pool), params.amount);

        // repay the asset
        pool.repay(params.asset, params.amount, INTEREST_RATE_MODE, address(this));

        emit AssetRepaid(params.asset, params.amount, address(this));
    }
}
