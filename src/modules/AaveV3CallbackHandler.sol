// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {DataTypes} from "../common/DataTypes.sol";

contract AaveV3CallbackHandler is Context {
    function executeOperation(address, uint256, uint256 premium, address, bytes calldata params)
        external
        pure
        returns (DataTypes.CallbackData memory)
    {
        DataTypes.CallbackData memory callbackData = abi.decode(params, (DataTypes.CallbackData));
        callbackData.amountToApprove = callbackData.amountToApprove + premium;

        return callbackData;
    }
}
