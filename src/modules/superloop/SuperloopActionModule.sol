// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Errors} from "../../common/Errors.sol";
import {ISuperloop} from "../../interfaces/ISuperloop.sol";
import {SuperloopStorage} from "../../core/lib/SuperloopStorage.sol";

/**
 * @title SuperloopActionModule
 * @author Superlend
 * @notice Abstract contract for Superloop action modules providing base functionality
 * @dev Provides common Superloop integration and execution context validation
 */
abstract contract SuperloopActionModule {
    /**
     * @notice The address of the vault
     */
    address public immutable vault;

    /**
     * @notice Constructor to initialize the Superloop action module
     * @param vaultAddress The address of the vault
     */
    constructor(address vaultAddress) {
        vault = vaultAddress;
    }

    /**
     * @notice Modifier to ensure the function is called within an execution context
     * @dev Reverts if not in execution context
     */
    modifier onlyExecutionContext() {
        require(_isExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
        _;
    }

    /**
     * @notice Internal function to check if the current call is within an execution context
     * @return True if in execution context, false otherwise
     */
    function _isExecutionContext() internal view returns (bool) {
        return SuperloopStorage.isInExecutionContext();
    }
}
