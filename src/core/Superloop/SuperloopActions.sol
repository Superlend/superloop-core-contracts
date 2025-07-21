// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";
import {SuperloopStorage} from "../lib/SuperLoopStorage.sol";
import {Errors} from "../../common/Errors.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

abstract contract SuperloopActions {
    function operate(DataTypes.ModuleExecutionData[] memory moduleExecutionData) external {
        // TODO : add restriction
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
