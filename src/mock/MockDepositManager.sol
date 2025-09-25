// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDepositManager} from "../interfaces/IDepositManager.sol";

/**
 * @title MockDepositManager
 * @author Superlend
 * @notice Mock deposit manager for testing purposes
 * @dev Provides basic deposit manager functionality for testing
 */
contract MockDepositManager is IDepositManager {
    using SafeERC20 for IERC20;

    uint256 public constant MOCK_SHARES_PER_TOKEN = 1e18; // 1:1 ratio for simplicity

    /**
     * @notice Mock implementation of requestDeposit
     * @param amount The amount of tokens to deposit
     * @param onBehalfOf The address to receive the shares
     */
    function requestDeposit(uint256 amount, address onBehalfOf) external override {
        // In a real implementation, this would handle the deposit request
        // For testing, we just return a mock number of shares
    }
}
