// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {IStakingCore} from "../../../interfaces/IStakingCore.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {Errors} from "../../../common/Errors.sol";
import {SuperloopStorage} from "../../../core/lib/SuperloopStorage.sol";

contract HyperbeatStakingModule is Context {
    IStakingCore public immutable stakingCore;

    event HyperbeatStaked(uint256 assets, address caller);

    constructor(address _stakingManager) {
        stakingCore = IStakingCore(_stakingManager);
    }

    function execute(DataTypes.StakeParams memory params) external onlyExecutionContext {
        stakingCore.stake{value: params.assets}();

        emit HyperbeatStaked(params.assets, _msgSender());
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
