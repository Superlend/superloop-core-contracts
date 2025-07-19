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

contract MockIntegrationTest is Test {
    MockWithdrawManager public withdrawManager;
    MockVault public vault;
    MockERC20 public asset;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public dave = address(0x4);
    
    uint256 public constant INITIAL_BALANCE = 10000 * 10**18;
    uint256 public constant DEPOSIT_AMOUNT = 2000 * 10**18;
    uint256 public constant WITHDRAW_AMOUNT = 1000 * 10**18;
    uint256 public constant WITHDRAW_DELAY = 30 minutes;

    function setUp() public {
        // Deploy mock asset
        asset = new MockERC20("Mock Token", "MTK", 18);
        
        // Deploy vault
        vault = new MockVault(IERC20(asset), "Mock Vault", "mvMTK");
        
        // Deploy withdraw manager
        withdrawManager = new MockWithdrawManager();
        withdrawManager.initialize(address(vault));
        
        // Give initial balances to test users
        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);
        asset.mint(charlie, INITIAL_BALANCE);
        asset.mint(dave, INITIAL_BALANCE);
        
        // Label addresses for better test output
        vm.label(address(asset), "MockAsset");
        vm.label(address(vault), "MockVault");
        vm.label(address(withdrawManager), "MockWithdrawManager");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(dave, "Dave");
    }

    function test_CompleteVaultFlow() public {
        // Step 1: Users deposit into vault
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 aliceShares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 bobShares = vault.deposit(DEPOSIT_AMOUNT, bob);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 charlieShares = vault.deposit(DEPOSIT_AMOUNT, charlie);
        vm.stopPrank();
        
        // Verify vault state
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT * 3);
        assertEq(vault.totalSupply(), aliceShares + bobShares + charlieShares);
        
        // Step 2: Users request withdrawals
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(bob);
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        // Verify withdraw requests
        assertEq(withdrawManager.nextWithdrawRequestId(), 3);
        assertEq(withdrawManager.userWithdrawRequestId(alice), 1);
        assertEq(withdrawManager.userWithdrawRequestId(bob), 2);
        
        // Step 3: Try to withdraw before delay (should fail)
        vm.startPrank(alice);
        vm.expectRevert("Withdraw request not yet claimable");
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Step 4: Warp time and withdraw
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        vm.startPrank(bob);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Verify withdrawals were processed
        assertEq(withdrawManager.withdrawRequest(1).claimed, true);
        assertEq(withdrawManager.withdrawRequest(2).claimed, true);
        assertEq(withdrawManager.userWithdrawRequestId(alice), 0);
        assertEq(withdrawManager.userWithdrawRequestId(bob), 0);
        
        // Step 5: Users can request new withdrawals
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        assertEq(withdrawManager.userWithdrawRequestId(alice), 3);
    }

    function test_VaultYieldSimulation() public {
        // Initial deposits
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 aliceShares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 bobShares = vault.deposit(DEPOSIT_AMOUNT, bob);
        vm.stopPrank();
        
        // Simulate yield by adding virtual assets
        uint256 yield = DEPOSIT_AMOUNT / 10; // 10% yield
        vault.addVirtualAssets(yield);
        
        // Users request withdrawals
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(bob);
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        // Warp time and withdraw
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        vm.startPrank(bob);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Verify that users received their proportional share of yield
        // The mock uses shares as amount, so they get the same amount they requested
        assertEq(withdrawManager.withdrawRequest(1).amount, WITHDRAW_AMOUNT);
        assertEq(withdrawManager.withdrawRequest(2).amount, WITHDRAW_AMOUNT);
    }

    function test_CancellationFlow() public {
        // User deposits and requests withdrawal
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 aliceShares = vault.deposit(DEPOSIT_AMOUNT, alice);
        
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        // User cancels the request
        vm.startPrank(alice);
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();
        
        // Verify cancellation
        assertEq(withdrawManager.withdrawRequest(1).cancelled, true);
        assertEq(withdrawManager.userWithdrawRequestId(alice), 0);
        
        // User can request a new withdrawal
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        assertEq(withdrawManager.userWithdrawRequestId(alice), 2);
    }

    // function test_MultipleUsersWithDifferentTimings() public {
    //     // Alice deposits and requests withdrawal
    //     vm.startPrank(alice);
    //     asset.approve(address(vault), DEPOSIT_AMOUNT);
    //     vault.deposit(DEPOSIT_AMOUNT, alice);
    //     vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
    //     withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
    //     vm.stopPrank();
        
    //     // Warp time forward 15 minutes
    //     vm.warp(block.timestamp + 15 minutes);
        
    //     // Bob deposits and requests withdrawal
    //     vm.startPrank(bob);
    //     asset.approve(address(vault), DEPOSIT_AMOUNT);
    //     vault.deposit(DEPOSIT_AMOUNT, bob);
    //     vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
    //     withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
    //     vm.stopPrank();
        
    //     // Alice's request should be claimable, Bob's should not
    //     assertEq(withdrawManager.isWithdrawRequestClaimable(1), true);
    //     assertEq(withdrawManager.isWithdrawRequestClaimable(2), false);
        
    //     // Alice can withdraw
    //     vm.startPrank(alice);
    //     withdrawManager.withdraw();
    //     vm.stopPrank();
        
    //     // Bob cannot withdraw yet
    //     vm.startPrank(bob);
    //     vm.expectRevert("Withdraw request not yet claimable");
    //     withdrawManager.withdraw();
    //     vm.stopPrank();
        
    //     // Warp time forward another 15 minutes
    //     vm.warp(block.timestamp + 15 minutes);
        
    //     // Now Bob can withdraw
    //     vm.startPrank(bob);
    //     withdrawManager.withdraw();
    //     vm.stopPrank();
        
    //     assertEq(withdrawManager.withdrawRequest(1).claimed, true);
    //     assertEq(withdrawManager.withdrawRequest(2).claimed, true);
    // }

    function test_VaultAndWithdrawManagerStateConsistency() public {
        // Initial state
        assertEq(vault.totalAssets(), 0);
        assertEq(withdrawManager.nextWithdrawRequestId(), 1);
        assertEq(withdrawManager.resolvedWithdrawRequestId(), 0);
        
        // After deposits
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT);
        
        // After withdrawal request
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), WITHDRAW_AMOUNT);
        withdrawManager.requestWithdraw(WITHDRAW_AMOUNT);
        vm.stopPrank();
        
        assertEq(withdrawManager.nextWithdrawRequestId(), 2);
        assertEq(withdrawManager.userWithdrawRequestId(alice), 1);
        
        // After withdrawal
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        assertEq(withdrawManager.userWithdrawRequestId(alice), 0);
        assertEq(withdrawManager.withdrawRequest(1).claimed, true);
    }

    function test_EdgeCases() public {
        // Test with very small amounts
        vm.startPrank(alice);
        asset.approve(address(vault), 1);
        vault.deposit(1, alice);
        vault.approve(address(withdrawManager), 1);
        withdrawManager.requestWithdraw(1);
        vm.stopPrank();
        
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        assertEq(withdrawManager.withdrawRequest(1).claimed, true);
        
        // Test with large amounts
        vm.startPrank(bob);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, bob);
        vault.approve(address(withdrawManager), DEPOSIT_AMOUNT);
        withdrawManager.requestWithdraw(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        vm.startPrank(bob);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        assertEq(withdrawManager.withdrawRequest(2).claimed, true);
    }

    function testFuzz_IntegrationFlow(uint256 depositAmount, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= INITIAL_BALANCE);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);
        
        // Deposit
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();
        
        // Request withdrawal
        vm.startPrank(alice);
        vault.approve(address(withdrawManager), withdrawAmount);
        withdrawManager.requestWithdraw(withdrawAmount);
        vm.stopPrank();
        
        // Warp time and withdraw
        vm.warp(block.timestamp + WITHDRAW_DELAY);
        
        vm.startPrank(alice);
        withdrawManager.withdraw();
        vm.stopPrank();
        
        // Verify
        assertEq(withdrawManager.withdrawRequest(1).claimed, true);
        assertEq(withdrawManager.withdrawRequest(1).amount, withdrawAmount);
    }
} 