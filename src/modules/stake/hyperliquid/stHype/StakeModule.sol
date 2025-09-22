// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {IOverseerV1} from "../../../../interfaces/IOverseerV1.sol";
import {DataTypes} from "../../../../common/DataTypes.sol";
import {Errors} from "../../../../common/Errors.sol";
import {SuperloopStorage} from "../../../../core/lib/SuperloopStorage.sol";

contract StakeModule is Context {
    IOverseerV1 public immutable overseer;

    event Staked(uint256 assets, uint256 shares, address caller);

    constructor(address _overseer) {
        overseer = IOverseerV1(_overseer);
    }

    function execute(DataTypes.StakeParams memory params) external onlyExecutionContext {
        uint256 amountMinted = overseer.mint{value: params.assets}(address(this));

        emit Staked(params.assets, amountMinted, _msgSender());
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
