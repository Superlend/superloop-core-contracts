// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {IStakingManager} from "../../../interfaces/IStakingManager.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {Errors} from "../../../common/Errors.sol";
import {SuperloopStorage} from "../../../core/lib/SuperloopStorage.sol";

contract KinetiqStakeModule is Context {
    IStakingManager public immutable stakingManager;

    event KinetiqStaked(uint256 assets, address caller);

    constructor(address _stakingManager) {
        stakingManager = IStakingManager(_stakingManager);
    }

    function execute(DataTypes.StakeParams memory params) external onlyExecutionContext {
        stakingManager.stake{value: params.assets}();

        emit KinetiqStaked(params.assets, _msgSender());
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
