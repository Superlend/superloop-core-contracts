// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title AaveV3CallbackHandler
 * @author Superlend
 * @notice Callback handler for Aave V3 flashloan operations
 * @dev Handles flashloan callbacks and adjusts approval amounts to include premiums
 */
contract AaveV3CallbackHandler is Context {
    /**
     * @notice Executes the flashloan callback operation
     * @param premium The premium to be paid for the flashloan
     * @param params The encoded callback data parameters
     * @return callbackData The processed callback data with adjusted approval amount
     * @return success Always returns true to indicate successful execution
     */
    function executeOperation(address, uint256, uint256 premium, address, bytes calldata params)
        external
        pure
        returns (DataTypes.CallbackData memory, bool)
    {
        DataTypes.CallbackData memory callbackData = abi.decode(params, (DataTypes.CallbackData));
        callbackData.amountToApprove = callbackData.amountToApprove + premium;

        return (callbackData, true);
    }
}
