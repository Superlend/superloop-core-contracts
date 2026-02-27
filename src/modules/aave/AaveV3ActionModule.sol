// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {Errors} from "../../common/Errors.sol";
import {SuperloopStorage} from "../../core/lib/SuperloopStorage.sol";
import {DataTypes} from "../../common/DataTypes.sol";

/**
 * @title AaveV3ActionModule
 * @author Superlend
 * @notice Abstract contract for Aave V3 action modules providing base functionality
 * @dev Provides common Aave V3 integration and execution context validation
 */
abstract contract AaveV3ActionModule {
    /**
     * @notice The Aave V3 pool addresses provider
     */
    IPoolAddressesProvider public immutable poolAddressesProvider;

    /**
     * @notice The interest rate mode for Aave V3 operations (2 = variable rate)
     */
    uint256 public constant INTEREST_RATE_MODE = 2;

    /**
     * @notice Constructor to initialize the Aave V3 action module
     * @param poolAddressesProvider_ The address of the Aave V3 pool addresses provider
     */
    constructor(address poolAddressesProvider_) {
        poolAddressesProvider = IPoolAddressesProvider(poolAddressesProvider_);
    }

    /**
     * @notice Executes an Aave V3 action with the provided parameters
     * @param params The parameters for the Aave V3 action
     */
    function execute(DataTypes.AaveV3ActionParams memory params) external virtual;

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
