// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from "../../common/DataTypes.sol";

/**
 * @title WithdrawManagerCallbackHandler
 * @author Superlend
 * @notice Callback handler for withdraw manager operations
 * @dev Handles withdrawal callbacks and processes callback data
 */
contract WithdrawManagerCallbackHandler {
    function executeWithdraw(uint256, bytes calldata params)
        external
        pure
        returns (DataTypes.CallbackData memory, bool)
    {
        DataTypes.CallbackData memory callbackData = abi.decode(params, (DataTypes.CallbackData));
        callbackData.amountToApprove = callbackData.amountToApprove;

        return (callbackData, true);
    }
}
