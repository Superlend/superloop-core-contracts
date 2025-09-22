// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../../core/lib/SuperloopStorage.sol";
import {IWETH9} from "../../interfaces/IWETH9.sol";

contract UnwrapModule is Context {
    event Unwrapped(address indexed asset, uint256 amount, address caller);

    address public immutable underlyingToken;

    constructor(address _underlyingToken) {
        underlyingToken = _underlyingToken;
    }

    function execute(DataTypes.AaveV3ActionParams memory params) external onlyExecutionContext {
        require(params.asset == underlyingToken, Errors.INVALID_ASSET);

        IWETH9(params.asset).withdraw(params.amount);

        emit Unwrapped(params.asset, params.amount, _msgSender());
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
