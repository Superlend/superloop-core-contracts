// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {Errors} from "../common/Errors.sol";
import {SuperloopStorage} from "../core/lib/SuperloopStorage.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";

contract AaveV3EmodeModule is Context {
    event EModeCategorySet(address indexed user, uint8 emodeCategory);

    IPoolAddressesProvider public immutable poolAddressesProvider;

    constructor(address poolAddressesProvider_) {
        poolAddressesProvider = IPoolAddressesProvider(poolAddressesProvider_);
    }

    function execute(DataTypes.AaveV3EmodeParams memory params) external onlyExecutionContext {
        // get the pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // call set emode category
        pool.setUserEMode(params.emodeCategory);

        emit EModeCategorySet(_msgSender(), params.emodeCategory);
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
