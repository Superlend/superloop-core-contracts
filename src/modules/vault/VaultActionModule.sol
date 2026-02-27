// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../../core/lib/SuperloopStorage.sol";
import {DataTypes} from "../../common/DataTypes.sol";

/**
 * @title VaultActionModule
 * @author Superlend
 * @notice Abstract contract for vault action modules providing base functionality
 * @dev Provides common vault integration and execution context validation
 */
abstract contract VaultActionModule {
    /**
     * @notice Emitted when assets are supplied to a vault
     * @param vault The address of the vault
     * @param amount The amount of the underlying asset supplied
     * @param shares The amount of shares minted
     */
    event VaultSupplied(address indexed vault, uint256 amount, uint256 shares);

    /**
     * @notice Emitted when assets are withdrawn from a vault
     * @param vault The address of the vault
     * @param amount The amount of the underlying asset withdrawn
     * @param shares The amount of shares withdrawn
     */
    event VaultWithdrawn(address indexed vault, uint256 amount, uint256 shares);

    /**
     * @notice Executes a vault action with the provided parameters
     * @param params The parameters for the vault action
     */
    function execute(DataTypes.VaultActionParams memory params) external virtual;

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
