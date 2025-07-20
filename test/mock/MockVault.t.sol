// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockVault} from "../../src/mock/MockVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Mock ERC20 token for testing
contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

contract MockVaultTest is Test {
    MockVault public vault;
    MockERC20 public asset;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    uint256 public constant INITIAL_BALANCE = 10000 * 10 ** 18;
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 18;

    function setUp() public {
        // Deploy mock asset
        asset = new MockERC20("Mock Token", "MTK", 18);

        // Deploy vault
        vault = new MockVault(IERC20(asset), "Mock Vault", "mvMTK");

        // Give initial balances to test users
        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);
        asset.mint(charlie, INITIAL_BALANCE);

        // Label addresses for better test output
        vm.label(address(asset), "MockAsset");
        vm.label(address(vault), "MockVault");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
    }

    function test_Constructor() public {
        assertEq(vault.name(), "Mock Vault");
        assertEq(vault.symbol(), "mvMTK");
        assertEq(vault.decimals(), 20); // 18 + 2 (decimalsOffset)
        assertEq(address(vault.asset()), address(asset));
    }

    function test_InitialState() public {
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(asset.balanceOf(address(vault)), 0);
    }

    function test_Deposit() public {
        vm.startPrank(alice);

        uint256 assets = DEPOSIT_AMOUNT;
        uint256 shares = vault.previewDeposit(assets);

        // Approve vault to spend assets
        asset.approve(address(vault), assets);

        // Perform deposit
        uint256 mintedShares = vault.deposit(assets, alice);

        vm.stopPrank();

        // Verify shares were minted
        assertEq(mintedShares, shares);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalSupply(), shares);

        // Verify virtual assets were updated
        assertEq(vault.totalAssets(), assets);
        assertEq(vault.getVirtualAssets(), assets);

        // Verify no actual tokens were transferred
        assertEq(asset.balanceOf(address(vault)), 0);
    }

    function test_DepositWithDifferentReceiver() public {
        vm.startPrank(alice);

        uint256 assets = DEPOSIT_AMOUNT;
        asset.approve(address(vault), assets);

        // Deposit to bob's address
        uint256 shares = vault.deposit(assets, bob);

        vm.stopPrank();

        // Verify shares went to bob
        assertEq(vault.balanceOf(bob), shares);
        assertEq(vault.balanceOf(alice), 0);
    }

    function test_Mint() public {
        vm.startPrank(alice);

        uint256 shares = DEPOSIT_AMOUNT;
        uint256 assets = vault.previewMint(shares);

        asset.approve(address(vault), assets);

        uint256 assetsUsed = vault.mint(shares, alice);

        vm.stopPrank();

        assertEq(assetsUsed, assets);
        assertEq(vault.balanceOf(alice), shares);
    }

    function test_Withdraw() public {
        // First deposit
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        // Then withdraw
        vm.startPrank(alice);
        uint256 withdrawAssets = DEPOSIT_AMOUNT / 2;
        uint256 burnShares = vault.previewWithdraw(withdrawAssets);

        uint256 burnedShares = vault.withdraw(withdrawAssets, alice, alice);

        vm.stopPrank();

        assertEq(burnedShares, burnShares);
        assertEq(vault.balanceOf(alice), shares - burnShares);
        assertEq(vault.totalSupply(), shares - burnShares);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT - withdrawAssets);
    }

    function test_Redeem() public {
        // First deposit
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        // Then redeem
        vm.startPrank(alice);
        uint256 redeemShares = shares / 2;
        uint256 assets = vault.previewRedeem(redeemShares);

        uint256 assetsReceived = vault.redeem(redeemShares, alice, alice);

        vm.stopPrank();

        assertEq(assetsReceived, assets);
        assertEq(vault.balanceOf(alice), shares - redeemShares);
    }

    function test_PreviewFunctions() public {
        // Set some virtual assets to test preview functions
        vault.setVirtualAssets(DEPOSIT_AMOUNT);

        uint256 assets = 1000 * 10 ** 18;
        uint256 shares = 500 * 10 ** 18;

        uint256 previewDeposit = vault.previewDeposit(assets);
        uint256 previewMint = vault.previewMint(shares);
        uint256 previewWithdraw = vault.previewWithdraw(assets);
        uint256 previewRedeem = vault.previewRedeem(shares);

        assertGt(previewDeposit, 0);
        assertGt(previewMint, 0);
        assertGt(previewWithdraw, 0);
        assertGt(previewRedeem, 0);
    }

    function test_VirtualAssetsManagement() public {
        uint256 virtualAssets = 5000 * 10 ** 18;

        // Set virtual assets
        vault.setVirtualAssets(virtualAssets);
        assertEq(vault.totalAssets(), virtualAssets);
        assertEq(vault.getVirtualAssets(), virtualAssets);

        // Add virtual assets
        uint256 additionalAssets = 1000 * 10 ** 18;
        vault.addVirtualAssets(additionalAssets);
        assertEq(vault.totalAssets(), virtualAssets + additionalAssets);
        assertEq(vault.getVirtualAssets(), virtualAssets + additionalAssets);
    }

    function test_WithdrawWithInsufficientBalance() public {
        // Try to withdraw more than deposited
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);

        // Try to withdraw more than available
        vm.expectRevert();
        vault.withdraw(DEPOSIT_AMOUNT + 1, alice, alice);

        vm.stopPrank();
    }

    function test_RedeemWithInsufficientBalance() public {
        // Try to redeem more than owned
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);

        // Try to redeem more than owned
        vm.expectRevert();
        vault.redeem(shares + 1, alice, alice);

        vm.stopPrank();
    }

    // function test_WithdrawToZeroAddress() public {
    //     vm.startPrank(alice);
    //     asset.approve(address(vault), DEPOSIT_AMOUNT);
    //     vault.deposit(DEPOSIT_AMOUNT, alice);

    //     // Should revert when trying to withdraw to zero address
    //     vm.expectRevert();
    //     vault.withdraw(DEPOSIT_AMOUNT / 2, address(0), alice);

    //     vm.stopPrank();
    // }

    function test_MultipleUsers() public {
        // Alice deposits
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 aliceShares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 bobShares = vault.deposit(DEPOSIT_AMOUNT, bob);
        vm.stopPrank();

        // Charlie deposits
        vm.startPrank(charlie);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 charlieShares = vault.deposit(DEPOSIT_AMOUNT, charlie);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), aliceShares);
        assertEq(vault.balanceOf(bob), bobShares);
        assertEq(vault.balanceOf(charlie), charlieShares);
        assertEq(vault.totalSupply(), aliceShares + bobShares + charlieShares);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT * 3);
    }

    function test_AllowanceAndTransferFrom() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        // Alice approves bob to spend her shares
        vm.prank(alice);
        vault.approve(bob, shares / 2);

        // Bob transfers Alice's shares to Charlie
        vm.prank(bob);
        vault.transferFrom(alice, charlie, shares / 2);

        assertEq(vault.balanceOf(alice), shares / 2);
        assertEq(vault.balanceOf(charlie), shares / 2);
        assertEq(vault.balanceOf(bob), 0);
    }

    // function test_VirtualAssetsUnderflow() public {
    //     // Set virtual assets to a small amount
    //     vault.setVirtualAssets(100 * 10**18);

    //     // Try to withdraw more than available
    //     vm.startPrank(alice);
    //     asset.approve(address(vault), 100 * 10**18);
    //     vault.deposit(100 * 10**18, alice);

    //     // This should not revert due to the underflow protection in _withdraw
    //     vault.withdraw(200 * 10**18, alice, alice);

    //     vm.stopPrank();

    //     // Virtual assets should be 0, not negative
    //     assertEq(vault.totalAssets(), 0);
    //     assertEq(vault.getVirtualAssets(), 0);
    // }

    // function testFuzz_DepositAndWithdraw(uint256 depositAmount) public {
    //     vm.assume(depositAmount > 0 && depositAmount <= INITIAL_BALANCE);

    //     vm.startPrank(alice);
    //     asset.approve(address(vault), depositAmount);
    //     uint256 shares = vault.deposit(depositAmount, alice);

    //     // Withdraw half
    //     uint256 withdrawAmount = depositAmount / 2;
    //     vault.withdraw(withdrawAmount, alice, alice);

    //     vm.stopPrank();

    //     assertEq(vault.totalAssets(), depositAmount - withdrawAmount);
    //     assertLt(vault.balanceOf(alice), shares);
    // }
}
