// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IMorphoBase} from "morpho-blue/interfaces/IMorpho.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../../core/lib/SuperloopStorage.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MorphoFlashloanModule is Context {
    event MorphoFlashloanExecuted(address indexed asset, uint256 amount, address indexed borrower);

    IMorphoBase public immutable morpho;

    constructor(address morpho_) {
        morpho = IMorphoBase(morpho_);
    }

    function execute(DataTypes.MorphoFlashloanParams memory params) external onlyExecutionContext {
        // format the params for flashloan
        bytes memory callbackData = abi.encode(
            DataTypes.CallbackData({
                asset: params.asset,
                addressToApprove: address(morpho),
                amountToApprove: params.amount,
                executionData: params.callbackExecutionData
            })
        );

        // call the flashloan
        morpho.flashLoan(params.asset, params.amount, callbackData);

        // remove approval from morpho after flashloan is done
        SafeERC20.forceApprove(IERC20(params.asset), address(morpho), 0);

        emit MorphoFlashloanExecuted(params.asset, params.amount, address(this));
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
