// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "./TestBase.sol";
import {console} from "forge-std/console.sol";
import {Superloop} from "../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {Errors} from "../../src/common/Errors.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {WithdrawManager} from "../../src/core/WithdrawManager/WithdrawManager.sol";

contract WithdrawManagerTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user1;
    address public user2;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](5);
        modules[0] = address(supplyModule);
        modules[1] = address(withdrawModule);
        modules[2] = address(borrowModule);
        modules[3] = address(repayModule);
        modules[4] = address(dexModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "XTZ Vault",
            symbol: "XTZV",
            supplyCap: 100000 * 10 ** 18,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury
        });
        superloopImplementation = new Superloop();
        proxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(superloopImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(payable(address(proxy)));

        _deployAccountant(address(superloop));
        _deployWithdrawManager(address(superloop));
        _deployDepositManager(address(superloop));

        superloop.setAccountantModule(address(accountant));
        superloop.setWithdrawManagerModule(address(withdrawManager));
        superloop.setDepositManagerModule(address(depositManager));

        vm.stopPrank();

        vm.label(address(superloop), "superloop");
        vm.label(user1, "user1");
        vm.label(user2, "user2");
    }

    function test_Initialize() public view {
        address vault = withdrawManager.vault();
        address asset = withdrawManager.asset();
        uint256 nextGeneralRequestId = withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.GENERAL);
        uint256 nextInstantRequestId = withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.INSTANT);
        uint256 nextPriorityRequestId = withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.PRIORITY);
        uint256 nextDeferredRequestId = withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.DEFERRED);

        assertEq(vault, address(superloop));
        assertEq(asset, XTZ);
        assertEq(nextGeneralRequestId, 1);
        assertEq(nextInstantRequestId, 1);
        assertEq(nextPriorityRequestId, 1);
        assertEq(nextDeferredRequestId, 1);
    }

    // ============ requestWithdraw Tests ============

    function test_requestWithdraw_Success() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares
        deal(address(superloop), user1, shares);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);

        // Expect the WithdrawRequested event
        vm.expectEmit(true, true, true, true);
        emit WithdrawManager.WithdrawRequested(user1, shares, 1, requestType);

        withdrawManager.requestWithdraw(shares, requestType);
        vm.stopPrank();

        // Verify the withdraw request was created
        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1, requestType);

        assertEq(request.shares, shares);
        assertEq(request.sharesProcessed, 0);
        assertEq(request.amountClaimable, 0);
        assertEq(request.amountClaimed, 0);
        assertEq(request.user, user1);
        assertEq(uint256(request.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

        // Verify user's withdraw request ID was set
        uint256 userRequestId = withdrawManager.userWithdrawRequestId(user1, requestType);
        assertEq(userRequestId, 1);

        // Verify shares were transferred to withdraw manager
        assertEq(IERC20(address(superloop)).balanceOf(address(withdrawManager)), shares);
        assertEq(IERC20(address(superloop)).balanceOf(user1), 0);
    }

    function test_requestWithdraw_ZeroShares() public {
        uint256 shares = 0;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.INVALID_SHARES_AMOUNT));
        withdrawManager.requestWithdraw(shares, requestType);
        vm.stopPrank();
    }

    function test_requestWithdraw_ZeroExpectedAmount() public {
        uint256 shares = 1; // Very small amount that would result in 0 expected withdraw amount
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares
        deal(address(superloop), user1, shares);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);

        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        withdrawManager.requestWithdraw(shares, requestType);
        vm.stopPrank();
    }

    function test_requestWithdraw_ActiveRequestExists() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares
        deal(address(superloop), user1, shares * 2);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares * 2);

        // Make first withdraw request
        withdrawManager.requestWithdraw(shares, requestType);

        // Try to make another withdraw request - should fail
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_ACTIVE));
        withdrawManager.requestWithdraw(shares, requestType);
        vm.stopPrank();
    }

    function test_requestWithdraw_InsufficientBalance() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Don't give user1 any vault shares
        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);

        vm.expectRevert();
        withdrawManager.requestWithdraw(shares, requestType);
        vm.stopPrank();
    }

    function test_requestWithdraw_DifferentRequestTypes() public {
        uint256 shares = 1000 * 10 ** 18;

        // Give user1 some vault shares
        deal(address(superloop), user1, shares * 4);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares * 4);

        // Test all request types
        withdrawManager.requestWithdraw(shares, DataTypes.WithdrawRequestType.GENERAL);
        withdrawManager.requestWithdraw(shares, DataTypes.WithdrawRequestType.INSTANT);
        withdrawManager.requestWithdraw(shares, DataTypes.WithdrawRequestType.PRIORITY);
        withdrawManager.requestWithdraw(shares, DataTypes.WithdrawRequestType.DEFERRED);

        vm.stopPrank();

        // Verify all requests were created
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.GENERAL), 2);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.INSTANT), 2);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.PRIORITY), 2);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.DEFERRED), 2);
    }

    // ============ cancelWithdrawRequest Tests ============

    function test_cancelWithdrawRequest_Success() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares and make a withdraw request
        deal(address(superloop), user1, shares);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares, requestType);

        uint256 userBalanceBefore = IERC20(address(superloop)).balanceOf(user1);

        // Expect the WithdrawRequestCancelled event
        vm.expectEmit(true, true, true, true);
        emit WithdrawManager.WithdrawRequestCancelled(1, user1, shares, 0, requestType);

        withdrawManager.cancelWithdrawRequest(1, requestType);
        vm.stopPrank();

        // Verify the withdraw request was cancelled
        DataTypes.WithdrawRequestData memory request = withdrawManager.withdrawRequest(1, requestType);

        assertEq(uint256(request.state), uint256(DataTypes.RequestProcessingState.CANCELLED));

        // Verify user's withdraw request ID was cleared
        uint256 userRequestId = withdrawManager.userWithdrawRequestId(user1, requestType);
        assertEq(userRequestId, 0);

        // Verify shares were refunded to user
        assertEq(IERC20(address(superloop)).balanceOf(user1), userBalanceBefore + shares);
        assertEq(IERC20(address(superloop)).balanceOf(address(withdrawManager)), 0);
    }

    function test_cancelWithdrawRequest_WrongOwner() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares and make a withdraw request
        deal(address(superloop), user1, shares);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares, requestType);
        vm.stopPrank();

        // Try to cancel from user2 - should fail
        vm.startPrank(user2);
        vm.expectRevert(bytes(Errors.CALLER_NOT_WITHDRAW_REQUEST_OWNER));
        withdrawManager.cancelWithdrawRequest(1, requestType);
        vm.stopPrank();
    }

    function test_cancelWithdrawRequest_AlreadyCancelled() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares and make a withdraw request
        deal(address(superloop), user1, shares);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares, requestType);

        // Cancel the request
        withdrawManager.cancelWithdrawRequest(1, requestType);

        // Try to cancel again - should fail
        vm.expectRevert(bytes(Errors.INVALID_WITHDRAW_REQUEST_STATE));
        withdrawManager.cancelWithdrawRequest(1, requestType);
        vm.stopPrank();
    }

    function test_cancelWithdrawRequest_NonExistentRequest() public {
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_NOT_FOUND));
        withdrawManager.cancelWithdrawRequest(999, requestType); // Non-existent request ID
        vm.stopPrank();
    }

    // ============ withdraw Tests ============

    function test_withdraw_NoRequestFound() public {
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_NOT_FOUND));
        withdrawManager.withdraw(requestType);
        vm.stopPrank();
    }

    function test_withdraw_WrongOwner() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares and make a withdraw request
        deal(address(superloop), user1, shares);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares, requestType);
        vm.stopPrank();

        // Try to withdraw from user2 - should fail
        vm.startPrank(user2);
        vm.expectRevert();
        withdrawManager.withdraw(requestType);
        vm.stopPrank();
    }

    function test_withdraw_RequestActive() public {
        uint256 shares = 1000 * 10 ** 18;
        DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

        // Give user1 some vault shares and make a withdraw request
        deal(address(superloop), user1, shares);

        vm.startPrank(user1);
        IERC20(address(superloop)).approve(address(withdrawManager), shares);
        withdrawManager.requestWithdraw(shares, requestType);

        // Try to withdraw immediately - should fail (request is still active/unprocessed)
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_ACTIVE));
        withdrawManager.withdraw(requestType);
        vm.stopPrank();
    }

    // ============ resolveWithdrawRequests Tests ============

    function test_resolveWithdrawRequests_OnlyVault() public {
        DataTypes.ResolveWithdrawRequestsData memory data = DataTypes.ResolveWithdrawRequestsData({
            shares: 1000 * 10 ** 18,
            requestType: DataTypes.WithdrawRequestType.GENERAL,
            callbackExecutionData: ""
        });

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT));
        withdrawManager.resolveWithdrawRequests(data);
        vm.stopPrank();
    }

    function test_resolveWithdrawRequests_ZeroShares() public {
        DataTypes.ResolveWithdrawRequestsData memory data = DataTypes.ResolveWithdrawRequestsData({
            shares: 0,
            requestType: DataTypes.WithdrawRequestType.GENERAL,
            callbackExecutionData: ""
        });

        vm.startPrank(address(superloop));
        vm.expectRevert(bytes(Errors.INVALID_SHARES_AMOUNT));
        withdrawManager.resolveWithdrawRequests(data);
        vm.stopPrank();
    }

    function test_resolveWithdrawRequests_ExceedsPending() public {
        DataTypes.ResolveWithdrawRequestsData memory data = DataTypes.ResolveWithdrawRequestsData({
            shares: 1000 * 10 ** 18,
            requestType: DataTypes.WithdrawRequestType.GENERAL,
            callbackExecutionData: ""
        });

        vm.startPrank(address(superloop));
        vm.expectRevert(bytes(Errors.INVALID_SHARES_AMOUNT));
        withdrawManager.resolveWithdrawRequests(data);
        vm.stopPrank();
    }

    // TODO: Test partial cancellation, partial processing, and resolveWithdrawRequests functions
    // NOTE: Cannot test these functions without manipulating the internal state, so will be tested in integration tests
}
