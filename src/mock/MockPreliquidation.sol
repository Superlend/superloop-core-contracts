// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

contract MockPreliquidation {
    function preliquidate(bytes32, DataTypes.CallType, bytes calldata) external returns (bool) {
        return true;
    }
}
