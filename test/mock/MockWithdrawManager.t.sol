// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockWithdrawManager} from "../../src/mock/MockWithdrawManager.sol";
import {MockVault} from "../../src/mock/MockVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";

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

contract MockWithdrawManagerTest is Test {
    MockWithdrawManager public withdrawManager;
    MockVault public vault;
    MockERC20 public asset;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public vaultAddress;
    
    uint256 public constant INITIAL_BALANCE = 10000 * 10**18;
    uint256 public constant WITHDRAW_AMOUNT = 1000 * 10**18;
    uint256 public constant WITHDRAW_DELAY = 30 minutes;

    function setUp() public {
        // Deploy mock asset
        asset = new MockERC20("Mock Token", "MTK", 18);
        
        // Deploy vault
        vault = new MockVault(IERC20(asset), "Mock Vault", "mvMTK");
        vaultAddress = address(vault);
        
        // Deploy withdraw manager
        withdrawManager = new MockWithdrawManager();
        withdrawManager.initialize(vaultAddress);
        
        // Give initial balances to test users
        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);
        asset.mint(charlie, INITIAL_BALANCE);
        
        // Give vault shares to users for testing
        vm.startPrank(alice);
        asset.approve(vaultAddress, INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        asset.approve(vaultAddress, INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE, bob);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        asset.approve(vaultAddress, INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE, charlie);
        vm.stopPrank();
        
        // Label addresses for better test output
        vm.label(address(asset), "MockAsset");
        vm.label(vaultAddress, "MockVault");
        vm.label(address(withdrawManager), "MockWithdrawManager");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
    }

    function test_ConstructorAndInitialize() public {
        assertEq(withdrawManager.vault(), vaultAddress);
        assertEq(withdrawManager.asset(), address(asset));
        assertEq(withdrawManager.nextWithdrawRequestId(), 1);
        assertEq(withdrawManager.resolvedWithdrawRequestId(), 0);
    }

    function test_RequestWithdraw() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        uint256 aliceVaultBalance = vault.balanceOf(alice);
        
        // Approve withdraw manager to spend vault shares
        vault.approve(address(withdrawManager), shares);
        
        // Request withdraw
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Verify withdraw request was created
        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1);
        assertEq(request.user, alice);
        assertEq(request.shares, shares);
        assertEq(request.amount, shares); // In mock, amount equals shares
        assertEq(request.claimed, false);
        assertEq(request.cancelled, false);
        
        // Verify user's withdraw request ID was set
        assertEq(withdrawManager.userWithdrawRequestId(alice), 1);
        
        // Verify next withdraw request ID was incremented
        assertEq(withdrawManager.nextWithdrawRequestId(), 2);
        
        // Verify vault shares were transferred to withdraw manager
        assertEq(vault.balanceOf(address(withdrawManager)), shares);
        assertEq(vault.balanceOf(alice), aliceVaultBalance - shares);
    }

    function test_RequestWithdrawWithZeroAmount() public {
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), 0);
        
        vm.expectRevert(); // Should revert with INVALID_AMOUNT
        withdrawManager.requestWithdraw(0);
        
        vm.stopPrank();
    }

    function test_RequestWithdrawWithInsufficientBalance() public {
        vm.startPrank(alice);
        uint256 aliceBalance = vault.balanceOf(alice);
        
        vault.approve(address(withdrawManager), aliceBalance + 1);
        
        vm.expectRevert(); // Should revert with insufficient balance
        withdrawManager.requestWithdraw(aliceBalance + 1);
        
        vm.stopPrank();
    }

    function test_RequestWithdrawWithActiveRequest() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        // Try to request another withdraw while first is active
        vault.approve(address(withdrawManager), shares);
        vm.expectRevert(); // Should revert with WITHDRAW_REQUEST_ACTIVE
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
    }

    function test_GetWithdrawRequestState() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Check state immediately after request
        DataTypes.WithdrawRequestState state = withdrawManager.getWithdrawRequestState(1);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.UNPROCESSED));
        
        // Check state after 30 minutes
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        state = withdrawManager.getWithdrawRequestState(1);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.CLAIMABLE));
    }

    function test_WithdrawAfterDelay() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Try to withdraw before 30 minutes
        vm.startPrank(alice);
        vm.expectRevert("Withdraw request not yet claimable");
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Warp time forward 30 minutes
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        
        // Now withdraw should succeed
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Verify request was marked as claimed
        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1);
        assertEq(request.claimed, true);
        
        // Verify user's withdraw request ID was reset
        assertEq(withdrawManager.userWithdrawRequestId(alice), 0);
        
        // Verify state is CLAIMED
        DataTypes.WithdrawRequestState state = withdrawManager.getWithdrawRequestState(1);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.CLAIMED));
    }

    function test_WithdrawNonExistentRequest() public {
        vm.startPrank(alice);
        
        vm.expectRevert(); // Should revert with WITHDRAW_REQUEST_NOT_FOUND
        withdrawManager.withdraw();
        
        vm.stopPrank();
    }

    function test_WithdrawAlreadyClaimed() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Warp time and withdraw
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Try to withdraw again
        vm.startPrank(alice);
        vm.expectRevert(); // Should revert with WITHDRAW_REQUEST_ALREADY_CLAIMED
        withdrawManager.withdraw();
        vm.stopPrank();
    }

    function test_CancelWithdrawRequest() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        uint256 aliceVaultBalance = vault.balanceOf(alice);
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Cancel the request
        vm.startPrank(alice);
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();
        
        // Verify request was marked as cancelled
        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1);
        assertEq(request.cancelled, true);
        
        // Verify user's withdraw request ID was reset
        assertEq(withdrawManager.userWithdrawRequestId(alice), 0);
        
        // Verify vault shares were returned to user
        assertEq(vault.balanceOf(alice), aliceVaultBalance);
        assertEq(vault.balanceOf(address(withdrawManager)), 0);
        
        // Verify state is CANCELLED
        DataTypes.WithdrawRequestState state = withdrawManager.getWithdrawRequestState(1);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.CANCELLED));
    }

    function test_CancelNonExistentRequest() public {
        vm.startPrank(alice);
        
        vm.expectRevert(); // Should revert with WITHDRAW_REQUEST_NOT_FOUND
        withdrawManager.cancelWithdrawRequest(999);
        
        vm.stopPrank();
    }

    function test_CancelRequestFromWrongUser() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Bob tries to cancel Alice's request
        vm.startPrank(bob);
        vm.expectRevert(); // Should revert with CALLER_NOT_WITHDRAW_REQUEST_OWNER
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();
    }

    function test_CancelAlreadyClaimedRequest() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Warp time and withdraw
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Try to cancel already claimed request
        vm.startPrank(alice);
        vm.expectRevert(); // Should revert with WITHDRAW_REQUEST_ALREADY_CLAIMED
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();
    }

    function test_ResolveWithdrawRequests() public {
        // This function should do nothing in the mock
        vm.prank(vaultAddress);
        withdrawManager.resolveWithdrawRequests(10);
        
        // Verify nothing changed
        assertEq(withdrawManager.resolvedWithdrawRequestId(), 0);
    }

    function test_MultipleWithdrawRequests() public {
        // Alice requests withdraw
        vm.startPrank(alice);
        uint256 aliceShares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), aliceShares);
        withdrawManager.requestWithdraw(aliceShares);
        vm.stopPrank();
        
        // Bob requests withdraw
        vm.startPrank(bob);
        uint256 bobShares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), bobShares);
        withdrawManager.requestWithdraw(bobShares);
        vm.stopPrank();
        
        // Charlie requests withdraw
        vm.startPrank(charlie);
        uint256 charlieShares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), charlieShares);
        withdrawManager.requestWithdraw(charlieShares);
        vm.stopPrank();
        
        // Verify all requests were created
        assertEq(withdrawManager.nextWithdrawRequestId(), 4);
        assertEq(withdrawManager.userWithdrawRequestId(alice), 1);
        assertEq(withdrawManager.userWithdrawRequestId(bob), 2);
        assertEq(withdrawManager.userWithdrawRequestId(charlie), 3);
        
        // Warp time and withdraw all
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        vm.startPrank(bob);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        vm.startPrank(charlie);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Verify all requests were claimed
        assertEq(withdrawManager.withdrawRequest(1).claimed, true);
        assertEq(withdrawManager.withdrawRequest(2).claimed, true);
        assertEq(withdrawManager.withdrawRequest(3).claimed, true);
    }

    function test_HelperFunctions() public {
        vm.startPrank(alice);
        
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        
        vm.stopPrank();
        
        // Test getWithdrawRequestTimestamp
        uint256 timestamp = withdrawManager.getWithdrawRequestTimestamp(1);
        assertEq(timestamp, block.timestamp);
        
        // Test isWithdrawRequestClaimable
        bool claimable = withdrawManager.isWithdrawRequestClaimable(1);
        assertEq(claimable, false);
        
        // Warp time and test again
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        claimable = withdrawManager.isWithdrawRequestClaimable(1);
        assertEq(claimable, true);
    }

    function test_WithdrawRequestStates() public {
        // Test NOT_EXIST state
        DataTypes.WithdrawRequestState state = withdrawManager.getWithdrawRequestState(999);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.NOT_EXIST));
        
        // Create a request
        vm.startPrank(alice);
        uint256 shares = WITHDRAW_AMOUNT;
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        vm.stopPrank();
        
        // Test UNPROCESSED state
        state = withdrawManager.getWithdrawRequestState(1);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.UNPROCESSED));
        
        // Warp time and test CLAIMABLE state
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        state = withdrawManager.getWithdrawRequestState(1);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.CLAIMABLE));
        
        // Withdraw and test CLAIMED state
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        state = withdrawManager.getWithdrawRequestState(1);
        assertEq(uint256(state), uint256(DataTypes.WithdrawRequestState.CLAIMED));
    }

    function test_OnlyVaultModifier() public {
        // Only vault should be able to call resolveWithdrawRequests
        vm.startPrank(alice);
        vm.expectRevert(); // Should revert with CALLER_NOT_VAULT
        withdrawManager.resolveWithdrawRequests(10);
        vm.stopPrank();
        
        // Vault should be able to call it
        vm.prank(vaultAddress);
        withdrawManager.resolveWithdrawRequests(10); // Should not revert
    }

    function testFuzz_WithdrawRequest(uint256 shares) public {
        vm.assume(shares > 0 && shares <= vault.balanceOf(alice));
        
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares);
        vm.stopPrank();
        
        // Warp time and withdraw
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Verify request was claimed
        assertEq(withdrawManager.withdrawRequest(1).claimed, true);
    }
} 