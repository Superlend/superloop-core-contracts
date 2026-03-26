// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

interface IAccountantPlugin {
    /**
     * @notice Gets the total assets managed by the accountant
     * @param vault The address of the vault
     * @return The total amount of assets
     */
    function getTotalAssets(address vault) external view returns (uint256);
}
