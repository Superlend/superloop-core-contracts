// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {Errors} from "../common/Errors.sol";
import {SuperloopStorage} from "../core/lib/SuperloopStorage.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../common/DataTypes.sol";

abstract contract AaveV3ActionModule {
    IPoolAddressesProvider public immutable poolAddressesProvider;
    uint256 public constant INTEREST_RATE_MODE = 2;

    constructor(address poolAddressesProvider_) {
        poolAddressesProvider = IPoolAddressesProvider(poolAddressesProvider_);
    }

    function execute(DataTypes.AaveV3ActionParams memory params) external virtual;

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
