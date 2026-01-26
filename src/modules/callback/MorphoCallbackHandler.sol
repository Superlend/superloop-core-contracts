// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../../common/DataTypes.sol";

/**
 * @title MorphoCallbackHandler
 * @author Superlend
 * @notice Callback handler for Morpho flashloan operations
 * @dev Handles flashloan callbacks and adjusts approval amounts to include premiums
 */
contract MorphoCallbackHandler is Context {
    /**
     * @notice Executes the flashloan callback operation
     * @param params The encoded callback data parameters
     * @return callbackData The processed callback data
     * @return success Always returns true to indicate successful execution
     */
    function onMorphoFlashLoan(uint256, bytes calldata params)
        external
        pure
        returns (DataTypes.CallbackData memory, bool)
    {
        DataTypes.CallbackData memory callbackData = abi.decode(params, (DataTypes.CallbackData));
        return (callbackData, true);
    }
}
