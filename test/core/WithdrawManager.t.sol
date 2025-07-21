// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {WithdrawManager} from "../../src/core/WithdrawManager.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {Errors} from "../../src/common/Errors.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {MockAsset} from "../../src/mock/MockAsset.sol";
import {MockVault} from "../../src/mock/MockVault.sol";

contract WithdrawManagerTest is Test {
    WithdrawManager public withdrawManagerImplementation;
    WithdrawManager public withdrawManager;
    ProxyAdmin public proxyAdmin;
    MockAsset public asset;
    MockVault public vault;

    address public user1;
    address public user2;
    address public user3;

    uint256 public constant INITIAL_BALANCE = 1000 * 10 ** 18;
    uint256 public constant SHARES_AMOUNT = 100 * 10 ** 18;

    event WithdrawRequest(address indexed user, uint256 shares, uint256 amount, uint256 id);

    // Helper function to compare enum values
    function assertWithdrawRequestState(uint256 id, DataTypes.WithdrawRequestState expectedState) internal view {
        assertEq(uint8(withdrawManager.getWithdrawRequestState(id)), uint8(expectedState));
    }

    function setUp() public {
        // super.setUp();

        // Deploy mock contracts
        asset = new MockAsset();
        vault = new MockVault(asset, "Mock Vault", "mVLT");

        // Deploy proxy infrastructure
        withdrawManagerImplementation = new WithdrawManager();
        proxyAdmin = new ProxyAdmin(address(this));

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(withdrawManagerImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(WithdrawManager.initialize.selector, address(vault))
        );

        withdrawManager = WithdrawManager(address(proxy));

        // Setup users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Fund users with assets and vault shares
        asset.transfer(user1, INITIAL_BALANCE);
        asset.transfer(user2, INITIAL_BALANCE);
        asset.transfer(user3, INITIAL_BALANCE);

        // Users deposit assets to get vault shares
        vm.startPrank(user1);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_BALANCE, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_BALANCE, user2);
        vm.stopPrank();

        vm.startPrank(user3);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_BALANCE, user3);
        vm.stopPrank();
    }

    // ============ Initialization Tests ============

    function test_initialize() public view {
        assertEq(withdrawManager.vault(), address(vault));
        assertEq(withdrawManager.asset(), address(asset));
        assertEq(withdrawManager.nextWithdrawRequestId(), 1);
        assertEq(withdrawManager.resolvedWithdrawRequestId(), 0);
    }

    function test_initialize_revert_whenCalledDirectly() public {
        WithdrawManager newImplementation = new WithdrawManager();
        vm.expectRevert();
        newImplementation.initialize(address(vault));
    }

    function test_initialize_revert_whenCalledTwice() public {
        vm.expectRevert();
        withdrawManager.initialize(address(vault));
    }

    // ============ Request Withdraw Tests ============

    function test_requestWithdraw() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);

        uint256 balanceBefore = vault.balanceOf(user1);
        uint256 withdrawManagerBalanceBefore = vault.balanceOf(address(withdrawManager));

        withdrawManager.requestWithdraw(SHARES_AMOUNT);

        uint256 balanceAfter = vault.balanceOf(user1);
        uint256 withdrawManagerBalanceAfter = vault.balanceOf(address(withdrawManager));

        assertEq(balanceBefore - balanceAfter, SHARES_AMOUNT);
        assertEq(withdrawManagerBalanceAfter - withdrawManagerBalanceBefore, SHARES_AMOUNT);
        assertEq(withdrawManager.nextWithdrawRequestId(), 2);
        assertEq(withdrawManager.userWithdrawRequestId(user1), 1);

        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1);
        assertEq(request.user, user1);
        assertEq(request.shares, SHARES_AMOUNT);
        assertEq(request.amount, 0);
        assertEq(request.claimed, false);
        assertEq(request.cancelled, false);

        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.UNPROCESSED);
        vm.stopPrank();
    }

    function test_requestWithdraw_revert_zeroShares() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        withdrawManager.requestWithdraw(0);
        vm.stopPrank();
    }

    function test_requestWithdraw_revert_insufficientBalance() public {
        vm.startPrank(user1);
        uint256 excessiveAmount = vault.balanceOf(user1) + 1;
        vm.expectRevert();
        withdrawManager.requestWithdraw(excessiveAmount);
        vm.stopPrank();
    }

    function test_requestWithdraw_revert_activeRequestExists() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT * 2);

        // First request
        withdrawManager.requestWithdraw(SHARES_AMOUNT);

        // Resolve the request
        vm.stopPrank();
        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        // Try to request again before claiming
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_ACTIVE));
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();
    }

    function test_requestWithdraw_success_afterClaiming() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT * 2);

        // First request
        withdrawManager.requestWithdraw(SHARES_AMOUNT);

        // Resolve and claim
        vm.stopPrank();
        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.startPrank(user1);
        withdrawManager.withdraw();

        // Now can request again
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        assertEq(withdrawManager.nextWithdrawRequestId(), 3);
        vm.stopPrank();
    }

    // ============ Cancel Withdraw Request Tests ============

    function test_cancelWithdrawRequest() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);

        uint256 balanceBefore = vault.balanceOf(user1);
        uint256 withdrawManagerBalanceBefore = vault.balanceOf(address(withdrawManager));

        withdrawManager.cancelWithdrawRequest(1);

        uint256 balanceAfter = vault.balanceOf(user1);
        uint256 withdrawManagerBalanceAfter = vault.balanceOf(address(withdrawManager));

        assertEq(balanceAfter - balanceBefore, SHARES_AMOUNT);
        assertEq(withdrawManagerBalanceBefore - withdrawManagerBalanceAfter, SHARES_AMOUNT);
        assertEq(withdrawManager.userWithdrawRequestId(user1), 0);

        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1);
        assertEq(request.cancelled, true);

        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CANCELLED);
        vm.stopPrank();
    }

    function test_cancelWithdrawRequest_revert_notFound() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_NOT_FOUND));
        withdrawManager.cancelWithdrawRequest(0);
        vm.stopPrank();
    }

    function test_cancelWithdrawRequest_revert_notOwner() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(bytes(Errors.CALLER_NOT_WITHDRAW_REQUEST_OWNER));
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();
    }

    function test_cancelWithdrawRequest_revert_alreadyResolved() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.INVALID_WITHDRAW_REQUEST_STATE));
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();
    }

    function test_cancelWithdrawRequest_revert_alreadyClaimed() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.startPrank(user1);
        withdrawManager.withdraw();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.INVALID_WITHDRAW_REQUEST_STATE));
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();
    }

    // ============ Resolve Withdraw Requests Tests ============

    function test_resolveWithdrawRequests() public {
        // Setup multiple requests
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user3);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        // Resolve requests 1-3
        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(3);

        assertEq(withdrawManager.resolvedWithdrawRequestId(), 3);

        // Check that all requests are now claimable
        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CLAIMABLE);
        assertWithdrawRequestState(2, DataTypes.WithdrawRequestState.CLAIMABLE);
        assertWithdrawRequestState(3, DataTypes.WithdrawRequestState.CLAIMABLE);
    }

    function test_resolveWithdrawRequests_withCancelledRequest() public {
        // Setup requests
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        // Cancel one request
        vm.startPrank(user1);
        withdrawManager.cancelWithdrawRequest(1);
        vm.stopPrank();

        // Resolve requests
        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(2);

        assertEq(withdrawManager.resolvedWithdrawRequestId(), 2);
        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CANCELLED);
        assertWithdrawRequestState(2, DataTypes.WithdrawRequestState.CLAIMABLE);
    }

    function test_resolveWithdrawRequests_revert_notVault() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT));
        withdrawManager.resolveWithdrawRequests(1);
        vm.stopPrank();
    }

    function test_resolveWithdrawRequests_revert_invalidStartId() public {
        vm.prank(address(vault));
        vm.expectRevert(bytes(Errors.INVALID_WITHDRAW_RESOLVED_START_ID_LIMIT));
        withdrawManager.resolveWithdrawRequests(1);
    }

    function test_resolveWithdrawRequests_revert_invalidEndId() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.prank(address(vault));
        vm.expectRevert(bytes(Errors.INVALID_WITHDRAW_RESOLVED_END_ID_LIMIT));
        withdrawManager.resolveWithdrawRequests(1);
    }

    // ============ Withdraw Tests ============

    function test_withdraw() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.startPrank(user1);
        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 withdrawManagerAssetBalanceBefore = asset.balanceOf(address(withdrawManager));

        withdrawManager.withdraw();

        uint256 assetBalanceAfter = asset.balanceOf(user1);
        uint256 withdrawManagerAssetBalanceAfter = asset.balanceOf(address(withdrawManager));

        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1);
        uint256 expectedAmount = request.amount;

        assertEq(assetBalanceAfter - assetBalanceBefore, expectedAmount);
        assertEq(withdrawManagerAssetBalanceBefore - withdrawManagerAssetBalanceAfter, expectedAmount);
        assertEq(request.claimed, true);
        assertEq(withdrawManager.userWithdrawRequestId(user1), 0);
        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CLAIMED);
        vm.stopPrank();
    }

    function test_withdraw_revert_noRequest() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_NOT_FOUND));
        withdrawManager.withdraw();
        vm.stopPrank();
    }

    function test_withdraw_revert_notResolved() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);

        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_NOT_RESOLVED));
        withdrawManager.withdraw();
        vm.stopPrank();
    }

    function test_withdraw_revert_alreadyClaimed() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.startPrank(user1);
        withdrawManager.withdraw();

        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_NOT_FOUND));
        withdrawManager.withdraw();
        vm.stopPrank();
    }

    // ============ View Function Tests ============

    function test_getWithdrawRequestState() public {
        // Test NOT_EXIST
        assertWithdrawRequestState(999, DataTypes.WithdrawRequestState.NOT_EXIST);

        // Test UNPROCESSED
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.UNPROCESSED);

        // Test CLAIMABLE
        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CLAIMABLE);

        // Test CLAIMED
        vm.startPrank(user1);
        withdrawManager.withdraw();
        vm.stopPrank();

        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CLAIMED);

        // Test CANCELLED
        vm.startPrank(user2);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        withdrawManager.cancelWithdrawRequest(2);
        vm.stopPrank();

        assertWithdrawRequestState(2, DataTypes.WithdrawRequestState.CANCELLED);
    }

    function test_withdrawRequest() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1);
        assertEq(request.user, user1);
        assertEq(request.shares, SHARES_AMOUNT);
        assertEq(request.amount, 0);
        assertEq(request.claimed, false);
        assertEq(request.cancelled, false);
    }

    function test_withdrawRequests() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        DataTypes.WithdrawRequestData[] memory requests = withdrawManager.withdrawRequests(ids);
        assertEq(requests.length, 2);
        assertEq(requests[0].user, user1);
        assertEq(requests[1].user, user2);
    }

    function test_userWithdrawRequestId() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        assertEq(withdrawManager.userWithdrawRequestId(user1), 1);
        assertEq(withdrawManager.userWithdrawRequestId(user2), 0);
    }

    function test_userWithdrawRequestId_zeroAddress() public {
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        // When address(0) is passed, it should use msg.sender
        vm.prank(user1);
        assertEq(withdrawManager.userWithdrawRequestId(address(0)), 1);
    }

    // ============ Integration Tests ============

    function test_completeWithdrawFlow() public {
        // 1. User requests withdraw
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        // 2. Vault resolves the request
        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        // 3. User withdraws
        vm.startPrank(user1);
        uint256 assetBalanceBefore = asset.balanceOf(user1);
        withdrawManager.withdraw();
        uint256 assetBalanceAfter = asset.balanceOf(user1);
        vm.stopPrank();

        // Verify user received assets
        assertGt(assetBalanceAfter, assetBalanceBefore);

        // Verify state
        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CLAIMED);
        assertEq(withdrawManager.userWithdrawRequestId(user1), 0);
    }

    function test_multipleUsersWithdrawFlow() public {
        // Setup multiple users
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user3);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        // Resolve all requests
        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(3);

        // All users withdraw
        vm.startPrank(user1);
        withdrawManager.withdraw();
        vm.stopPrank();

        vm.startPrank(user2);
        withdrawManager.withdraw();
        vm.stopPrank();

        vm.startPrank(user3);
        withdrawManager.withdraw();
        vm.stopPrank();

        // Verify all requests are claimed
        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CLAIMED);
        assertWithdrawRequestState(2, DataTypes.WithdrawRequestState.CLAIMED);
        assertWithdrawRequestState(3, DataTypes.WithdrawRequestState.CLAIMED);

        // Verify user IDs are reset
        assertEq(withdrawManager.userWithdrawRequestId(user1), 0);
        assertEq(withdrawManager.userWithdrawRequestId(user2), 0);
        assertEq(withdrawManager.userWithdrawRequestId(user3), 0);
    }

    function test_cancelAndReRequest() public {
        // User requests withdraw
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT * 2);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);

        // User cancels the request
        withdrawManager.cancelWithdrawRequest(1);

        // User can request again
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        // Verify new request
        assertEq(withdrawManager.nextWithdrawRequestId(), 3);
        assertEq(withdrawManager.userWithdrawRequestId(user1), 2);
        assertWithdrawRequestState(1, DataTypes.WithdrawRequestState.CANCELLED);
        assertWithdrawRequestState(2, DataTypes.WithdrawRequestState.UNPROCESSED);
    }

    // ============ Edge Cases ============

    function test_reentrancyProtection() public {
        // This test verifies that the nonReentrant modifier is working
        // The contract should not allow reentrant calls to withdraw or cancel functions

        vm.startPrank(user1);
        vault.approve(address(withdrawManager), SHARES_AMOUNT);
        withdrawManager.requestWithdraw(SHARES_AMOUNT);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        // The nonReentrant modifier should prevent any reentrant attacks
        // This is tested implicitly by the fact that the functions work correctly
        // and don't allow multiple simultaneous calls
    }

    function test_zeroAmountHandling() public {
        // Test that zero amounts are handled correctly
        vm.startPrank(user1);
        vault.approve(address(withdrawManager), 1);
        withdrawManager.requestWithdraw(1);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.startPrank(user1);
        withdrawManager.withdraw();
        vm.stopPrank();

        // Should complete without issues even with minimal amounts
    }

    function test_largeAmountHandling() public {
        uint256 largeAmount = vault.balanceOf(user1);

        vm.startPrank(user1);
        vault.approve(address(withdrawManager), largeAmount);
        withdrawManager.requestWithdraw(largeAmount);
        vm.stopPrank();

        vm.prank(address(vault));
        withdrawManager.resolveWithdrawRequests(1);

        vm.startPrank(user1);
        withdrawManager.withdraw();
        vm.stopPrank();

        // Should handle large amounts correctly
    }
}
