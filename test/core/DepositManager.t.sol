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
import {DepositManager} from "../../src/core/DepositManager/DepositManager.sol";

contract DepositManagerTest is TestBase {
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
            accountantModule: mockModule,
            withdrawManagerModule: mockModule,
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
        superloop = Superloop(address(proxy));

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
        address vault = depositManager.vault();
        address asset = depositManager.asset();
        uint256 nextDepositRequestId = depositManager.nextDepositRequestId();

        assertEq(vault, address(superloop));
        assertEq(asset, XTZ);
        assertEq(nextDepositRequestId, 1);
    }

    // ============ requestDeposit Tests ============

    function test_requestDeposit_Success() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // Give user1 some XTZ tokens
        deal(XTZ, user1, depositAmount);

        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount);

        // Expect the DepositRequested event
        vm.expectEmit(true, true, true, true);
        emit DepositManager.DepositRequested(user1, depositAmount, 1);

        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();

        // Verify the deposit request was created
        DataTypes.DepositRequestData memory request = depositManager.depositRequest(1);

        assertEq(request.amount, depositAmount);
        assertEq(request.amountProcessed, 0);
        assertEq(request.user, user1);
        assertEq(uint256(request.state), uint256(DataTypes.RequestProcessingState.UNPROCESSED));

        // Verify user's deposit request ID was set
        (, uint256 userRequestId) = depositManager.userDepositRequest(user1);
        assertEq(userRequestId, 1);

        // Verify total pending deposits increased
        assertEq(depositManager.totalPendingDeposits(), depositAmount);

        // Verify tokens were transferred to deposit manager
        assertEq(IERC20(XTZ).balanceOf(address(depositManager)), depositAmount);
        assertEq(IERC20(XTZ).balanceOf(user1), 0);
    }

    function test_requestDeposit_OnBehalfOf() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // Give user1 some XTZ tokens
        deal(XTZ, user1, depositAmount);

        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount);

        // Expect the DepositRequested event with user2 as the beneficiary
        vm.expectEmit(true, true, true, true);
        emit DepositManager.DepositRequested(user2, depositAmount, 1);

        depositManager.requestDeposit(depositAmount, user2);
        vm.stopPrank();

        // Verify the deposit request was created for user2
        DataTypes.DepositRequestData memory request = depositManager.depositRequest(1);

        assertEq(request.user, user2);
        assertEq(request.amount, depositAmount);
    }

    function test_requestDeposit_ZeroAmount() public {
        uint256 depositAmount = 0;

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }

    function test_requestDeposit_SupplyCapExceeded() public {
        uint256 depositAmount = 200000 * 10 ** 18; // Exceeds supply cap of 100000 * 10**18

        // Give user1 enough XTZ tokens
        deal(XTZ, user1, depositAmount);

        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount);

        vm.expectRevert(bytes(Errors.SUPPLY_CAP_EXCEEDED));
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }

    function test_requestDeposit_ActiveRequestExists() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // Give user1 some XTZ tokens
        deal(XTZ, user1, depositAmount * 2);

        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount * 2);

        // Make first deposit request
        depositManager.requestDeposit(depositAmount, address(0));

        // Try to make another deposit request - should fail
        vm.expectRevert(bytes(Errors.DEPOSIT_REQUEST_ACTIVE));
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }

    function test_requestDeposit_InsufficientBalance() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // Don't give user1 any XTZ tokens
        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount);

        vm.expectRevert();
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }

    // // ============ cancelDepositRequest Tests ============

    function test_cancelDepositRequest_Success() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // Give user1 some XTZ tokens and make a deposit request
        deal(XTZ, user1, depositAmount);

        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));

        uint256 userBalanceBefore = IERC20(XTZ).balanceOf(user1);

        // Expect the DepositRequestCancelled event
        vm.expectEmit(true, true, true, true);
        emit DepositManager.DepositRequestCancelled(1, user1, depositAmount);

        depositManager.cancelDepositRequest(1);
        vm.stopPrank();

        // Verify the deposit request was cancelled
        DataTypes.DepositRequestData memory request = depositManager.depositRequest(1);

        assertEq(uint256(request.state), uint256(DataTypes.RequestProcessingState.CANCELLED));

        // Verify user's deposit request ID was cleared
        (, uint256 userRequestId) = depositManager.userDepositRequest(user1);
        assertEq(userRequestId, 0);

        // Verify total pending deposits decreased
        assertEq(depositManager.totalPendingDeposits(), 0);

        // Verify tokens were refunded to user
        assertEq(IERC20(XTZ).balanceOf(user1), userBalanceBefore + depositAmount);
        assertEq(IERC20(XTZ).balanceOf(address(depositManager)), 0);
    }

    function test_cancelDepositRequest_WrongOwner() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // Give user1 some XTZ tokens and make a deposit request
        deal(XTZ, user1, depositAmount);

        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();

        // Try to cancel from user2 - should fail
        vm.startPrank(user2);
        vm.expectRevert(bytes(Errors.CALLER_NOT_DEPOSIT_REQUEST_OWNER));
        depositManager.cancelDepositRequest(1);
        vm.stopPrank();
    }

    function test_cancelDepositRequest_AlreadyCancelled() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // Give user1 some XTZ tokens and make a deposit request
        deal(XTZ, user1, depositAmount);

        vm.startPrank(user1);
        IERC20(XTZ).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));

        // Cancel the request
        depositManager.cancelDepositRequest(1);

        // Try to cancel again - should fail
        vm.expectRevert(bytes(Errors.DEPOSIT_REQUEST_ALREADY_CANCELLED));
        depositManager.cancelDepositRequest(1);
        vm.stopPrank();
    }

    function test_cancelDepositRequest_NonExistentRequest() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.DEPOSIT_REQUEST_NOT_FOUND));
        depositManager.cancelDepositRequest(999); // Non-existent request ID
        vm.stopPrank();
    }

    // TODO: Test partial cancellation, already processed cancellation and reslveDepostRequest functions
    // NOTE: Cannot test these function without manipulating the internal state, so will be tested in integration tests
}
