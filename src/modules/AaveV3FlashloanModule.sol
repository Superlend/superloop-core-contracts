// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SuperloopStorage} from "../core/lib/SuperloopStorage.sol";
import {Errors} from "../common/Errors.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../common/DataTypes.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveV3FlashloanModule is Context {
    IPoolAddressesProvider public immutable poolAddressesProvider;

    constructor(address poolAddressesProvider_) {
        poolAddressesProvider = IPoolAddressesProvider(poolAddressesProvider_);
    }

    function execute(DataTypes.AaveV3FlashloanParams memory params) external onlyExecutionContext {
        // fetch pool
        IPool pool = IPool(poolAddressesProvider.getPool());

        // format the params for flashloan
        bytes memory callbackData = abi.encode(
            DataTypes.CallbackData({
                asset: params.asset,
                addressToApprove: address(pool),
                amountToApprove: params.amount,
                executionData: params.callbackExecutionData
            })
        );

        // call the flashloan
        pool.flashLoanSimple(address(this), params.asset, params.amount, callbackData, params.referralCode);

        // remove approval from pool after flashloan is done
        SafeERC20.forceApprove(IERC20(params.asset), address(pool), 0);
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
