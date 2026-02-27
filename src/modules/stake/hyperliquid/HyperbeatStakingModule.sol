// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {IStakingCore} from "../../../interfaces/IStakingCore.sol";
import {DataTypes} from "../../../common/DataTypes.sol";
import {Errors} from "../../../common/Errors.sol";
import {SuperloopStorage} from "../../../core/lib/SuperloopStorage.sol";

contract HyperbeatStakingModule is Context {
    IStakingCore public immutable stakingCore;

    event HyperbeatStaked(uint256 assets, address caller);

    constructor(address _stakingCore) {
        stakingCore = IStakingCore(_stakingCore);
    }

    function execute(DataTypes.StakeParams memory params) external onlyExecutionContext {
        // convert bytes to string
        string memory communityCode = abi.decode(params.data, (string));

        stakingCore.stake{value: params.assets}(communityCode);

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
