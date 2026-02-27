// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";
import {SuperloopStorage} from "../lib/SuperloopStorage.sol";
import {Errors} from "../../common/Errors.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

/**
 * @title SuperloopActions
 * @author Superlend
 * @notice Abstract contract providing module execution functionality for Superloop vaults
 * @dev Handles execution of registered modules with support for both CALL and DELEGATECALL operations
 */
abstract contract SuperloopActions {
    function _operate(DataTypes.ModuleExecutionData[] memory moduleExecutionData) internal {
        SuperloopStorage.beginExecutionContext();

        uint256 len = moduleExecutionData.length;
        for (uint256 i; i < len;) {
            // check if the module is registered
            if (!SuperloopStorage.getSuperloopStorage().registeredModules[moduleExecutionData[i].module]) {
                revert(Errors.MODULE_NOT_REGISTERED);
            }

            if (moduleExecutionData[i].executionType == DataTypes.CallType.CALL) {
                Address.functionCall(moduleExecutionData[i].module, moduleExecutionData[i].data);
            } else {
                Address.functionDelegateCall(moduleExecutionData[i].module, moduleExecutionData[i].data);
            }

            unchecked {
                ++i;
            }
        }
        SuperloopStorage.endExecutionContext();
    }

    function operateSelf(DataTypes.ModuleExecutionData[] memory moduleExecutionData)
        external
        onlyExecutionContext
        onlySelf
    {
        uint256 len = moduleExecutionData.length;
        for (uint256 i; i < len;) {
            // check if the module is registered
            if (!SuperloopStorage.getSuperloopStorage().registeredModules[moduleExecutionData[i].module]) {
                revert(Errors.MODULE_NOT_REGISTERED);
            }

            if (moduleExecutionData[i].executionType == DataTypes.CallType.CALL) {
                Address.functionCall(moduleExecutionData[i].module, moduleExecutionData[i].data);
            } else {
                Address.functionDelegateCall(moduleExecutionData[i].module, moduleExecutionData[i].data);
            }

            unchecked {
                ++i;
            }
        }
    }

    modifier onlyExecutionContext() {
        _isExecutionContext();
        _;
    }

    modifier onlySelf() {
        _onlySelf();
        _;
    }

    function _onlySelf() internal view {
        require(msg.sender == address(this), Errors.CALLER_NOT_SELF);
    }

    function _isExecutionContext() internal view {
        bool value = SuperloopStorage.isInExecutionContext();
        require(value, Errors.NOT_IN_EXECUTION_CONTEXT);
    }
}
