// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title MockPreliquidation
 * @author Superlend
 * @notice Mock preliquidation contract for testing purposes
 * @dev Provides mock preliquidation functionality that always returns success
 */
contract MockPreliquidation {
    function preliquidate(bytes32, DataTypes.CallType, bytes calldata) external returns (bool) {
        return true;
    }
}
