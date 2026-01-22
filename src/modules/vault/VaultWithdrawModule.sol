// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../../common/DataTypes.sol";

/**
 * @title VaultWithdrawModule
 * @author Superlend
 * @notice Module for withdrawing assets from a vault
 * @dev Extends IERC4626 to provide vault withdraw functionality
 */
contract VaultWithdrawModule {
    /**
     * @notice Emitted when assets are withdrawn from a vault
     * @param vault The address of the vault
     * @param amount The amount of the underlying asset withdrawn
     * @param shares The amount of shares withdrawn
     */
    event VaultWithdrawn(address indexed vault, uint256 amount, uint256 shares);

    /**
     * @notice Executes the withdraw operation
     * @param params The parameters for the withdraw operation
     */
    function execute(DataTypes.VaultActionParams memory params) external {
        uint256 amount =
            params.amount == type(uint256).max ? IERC4626(params.vault).maxWithdraw(address(this)) : params.amount;

        if (amount == 0) return;

        uint256 shares = IERC4626(params.vault).withdraw(amount, address(this), address(this));

        emit VaultWithdrawn(params.vault, amount, shares);
    }
}
