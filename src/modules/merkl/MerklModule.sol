// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IDistributor} from "./IDistributor.sol";
import {DataTypes} from "../../common/DataTypes.sol";
import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../../core/lib/SuperloopStorage.sol";

/**
 * @title MerklModule
 * @author Superlend
 * @notice Module for claiming rewards from Merkl
 * @dev Extends IDistributor to provide claiming functionality
 */
contract MerklModule {
    /**
     * @notice The distributor contract
     */
    IDistributor public immutable distributor;

    /**
     * @notice Emitted when rewards are claimed
     * @param users The addresses of the users who claimed rewards
     * @param tokens The addresses of the tokens claimed
     * @param amounts The amounts of the tokens claimed
     */
    event MerklRewardClaimed(address[] users, address[] tokens, uint256[] amounts);

    /**
     * @notice Constructor
     * @param _distributor The address of the distributor contract
     */
    constructor(address _distributor) {
        distributor = IDistributor(_distributor);
    }

    /**
     * @notice Executes the claim operation
     * @param params The parameters for the claim operation
     */
    function execute(DataTypes.MerklClaimParams memory params) external onlyExecutionContext {
        distributor.claim(params.users, params.tokens, params.amounts, params.proofs);

        emit MerklRewardClaimed(params.users, params.tokens, params.amounts);
    }

    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
