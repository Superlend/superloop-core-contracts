// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract MockVault is ERC4626 {
    using Math for uint256;

    // Track virtual assets for mock behavior
    uint256 private _virtualAssets;

    /**
     * @dev Constructor that sets up the vault with an underlying asset
     * @param asset_ The underlying ERC20 token that this vault represents
     * @param name_ The name of the vault shares token
     * @param symbol_ The symbol of the vault shares token
     */
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    ) ERC4626(asset_) ERC20(name_, symbol_) {}

    /**
     * @dev Override totalAssets to return virtual assets instead of actual balance
     * This allows the vault to simulate having assets without actually holding them
     */
    function totalAssets() public view virtual override returns (uint256) {
        return _virtualAssets;
    }

    /**
     * @dev Override _deposit to skip actual token transfer but still mint shares
     * This is the core mock behavior - no actual tokens are transferred
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        // Skip the actual token transfer from caller to this contract
        // SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);

        // Update virtual assets to simulate the deposit
        _virtualAssets += assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev Override _withdraw to skip actual token transfer but still burn shares
     * This is the core mock behavior - no actual tokens are transferred
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // Burn shares from owner
        _burn(owner, shares);

        // Skip the actual token transfer from this contract to receiver
        // SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        // Update virtual assets to simulate the withdrawal
        _virtualAssets = _virtualAssets > assets ? _virtualAssets - assets : 0;

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /**
     * @dev Function to manually set virtual assets for testing scenarios
     * @param assets The amount of virtual assets to set
     */
    function setVirtualAssets(uint256 assets) external {
        _virtualAssets = assets;
    }

    /**
     * @dev Function to add virtual assets (useful for simulating yield)
     * @param assets The amount of virtual assets to add
     */
    function addVirtualAssets(uint256 assets) external {
        _virtualAssets += assets;
    }

    /**
     * @dev Function to get current virtual assets
     * @return The current amount of virtual assets
     */
    function getVirtualAssets() external view returns (uint256) {
        return _virtualAssets;
    }

    /**
     * @dev Override _decimalsOffset to return 0 for standard behavior
     */
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return 2;
    }
}
