// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../common/DataTypes.sol";

/**
 * @title MockUniversalDexModule
 * @author Superlend
 * @notice Mock universal DEX module for testing purposes
 * @dev Provides configurable mock swap functionality for testing
 */
contract MockUniversalDexModule {
    uint256 public mockAmountOut;
    bool public shouldRevert;

    constructor(uint256 _mockAmountOut) {
        mockAmountOut = _mockAmountOut;
    }

    function executeAndExit(DataTypes.ExecuteSwapParams memory, address) external view returns (uint256) {
        if (shouldRevert) {
            revert("MockDexModule: execution failed");
        }
        return mockAmountOut;
    }

    function setMockAmountOut(uint256 _amount) external {
        mockAmountOut = _amount;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
}
