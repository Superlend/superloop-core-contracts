// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IWETH9
 * @notice Interface for the WETH9 contract
 * @dev This interface is used to interact with the WETH9 contract
 */
interface IWETH9 {
    /**
     * @notice Deposits ETH into the WETH contract
     * @dev This function is used to deposit ETH into the WETH contract
     */
    function deposit() external payable;

    /**
     * @notice Withdraws WETH from the WETH contract
     * @dev This function is used to withdraw WETH from the WETH contract
     * @param amount The amount of WETH to withdraw
     */
    function withdraw(uint256 amount) external;
}
