// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title IAaveV3PreliquidationFallbackHandler
 * @author Superlend
 * @notice Interface for Aave V3 preliquidation fallback handler
 */
interface IAaveV3PreliquidationFallbackHandler {
    function preliquidate(bytes32 id_, DataTypes.CallType, DataTypes.AaveV3ExecutePreliquidationParams memory params)
        external;

    function preliquidationParams(bytes32, DataTypes.CallType)
        external
        view
        returns (DataTypes.AaveV3PreliquidationParams memory);
}
