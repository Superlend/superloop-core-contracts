// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";

/**
 * @title DepositManagerCallbackHandler
 * @author Superlend
 * @notice Callback handler for deposit manager operations
 * @dev Handles deposit callbacks and processes callback data
 */
contract DepositManagerCallbackHandler {
    function executeDeposit(uint256, bytes calldata params)
        external
        pure
        returns (DataTypes.CallbackData memory, bool)
    {
        DataTypes.CallbackData memory callbackData = abi.decode(params, (DataTypes.CallbackData));
        callbackData.amountToApprove = callbackData.amountToApprove;

        return (callbackData, true);
    }
}
