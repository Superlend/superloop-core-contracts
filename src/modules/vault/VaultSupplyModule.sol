// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../../common/DataTypes.sol";

/**
 * @title VaultSupplyModule
 * @author Superlend
 * @notice Module for supplying assets to a vault
 * @dev Extends IERC4626 to provide vault supply functionality
 */
contract VaultSupplyModule {
    /**
     * @notice Emitted when assets are supplied to a vault
     * @param vault The address of the vault
     * @param amount The amount of the underlying asset supplied
     * @param shares The amount of shares minted
     */
    event VaultSupplied(address indexed vault, uint256 amount, uint256 shares);

    /**
     * @notice Executes the supply operation
     * @param params The parameters for the supply operation
     */
    function execute(DataTypes.VaultActionParams memory params) external {
        address underlyingAsset = IERC4626(params.vault).asset();
        uint256 amount =
            params.amount == type(uint256).max ? IERC20(underlyingAsset).balanceOf(address(this)) : params.amount;

        if (amount == 0) return;

        SafeERC20.forceApprove(IERC20(underlyingAsset), address(IERC4626(params.vault)), amount);

        uint256 shares = IERC4626(params.vault).deposit(amount, address(this));

        emit VaultSupplied(params.vault, amount, shares);
    }
}
