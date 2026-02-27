// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";

/**
 * @title AaveV3BorrowModule
 * @author Superlend
 * @notice Module for executing Aave V3 borrow operations
 * @dev Extends AaveV3ActionModule to provide borrowing functionality
 */
contract AaveV3BorrowModule is AaveV3ActionModule {
    /**
     * @notice Emitted when an asset is borrowed from Aave V3
     * @param asset The address of the borrowed asset
     * @param amount The amount of the asset borrowed
     * @param borrower The address of the borrower
     */
    event AssetBorrowed(address indexed asset, uint256 amount, address indexed borrower);

    /**
     * @notice Constructor to initialize the Aave V3 borrow module
     * @param poolAddressesProvider_ The address of the Aave V3 pool addresses provider
     */
    constructor(address poolAddressesProvider_) AaveV3ActionModule(poolAddressesProvider_) {}

    /**
     * @notice Executes a borrow operation on Aave V3
     * @param params The parameters for the borrow operation
     */
    function execute(DataTypes.AaveV3ActionParams memory params) external override onlyExecutionContext {
        // get the pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // borrow the asset
        pool.borrow(params.asset, params.amount, INTEREST_RATE_MODE, 0, address(this));

        emit AssetBorrowed(params.asset, params.amount, address(this));
    }
}
