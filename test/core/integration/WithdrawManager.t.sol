// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Errors} from "../../../src/common/Errors.sol";

contract WithdrawManagerTest is IntegrationBase {
    bool depositAll = true;
    DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.INSTANT;

    function setUp() public override {
        super.setUp();

        DataTypes.AaveV3EmodeParams memory params = DataTypes.AaveV3EmodeParams({emodeCategory: 3});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(emodeModule),
            data: abi.encodeWithSelector(emodeModule.execute.selector, params)
        });

        vm.prank(admin);
        superloop.operate(moduleExecutionData);
    }

    function test_initialize() public view {
        assertEq(withdrawManager.vault(), address(superloop));
        assertEq(withdrawManager.asset(), XTZ);
        assertEq(withdrawManager.nextWithdrawRequestId(requestType), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.INSTANT), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.PRIORITY), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.DEFERRED), 1);
    }

    function test_resolveWithdrawRequests() public {
        _createPartialDepositWithResolution(depositAll);

        // make 3 withdraw requests
        uint256 user1ShareBalance = superloop.balanceOf(user1);
        uint256 user2ShareBalance = superloop.balanceOf(user2);
        uint256 user3ShareBalance = superloop.balanceOf(user3);
        _makeWithdrawRequest(address(superloop), user1ShareBalance, user1, requestType);
        _makeWithdrawRequest(address(superloop), user2ShareBalance, user2, requestType);
        _makeWithdrawRequest(address(superloop), user3ShareBalance, user3, requestType);

        _resolveAllRequests(user1ShareBalance + user2ShareBalance + user3ShareBalance, requestType);
    }

    function test_resolveWithdrawRequestsWithPartials() public {
        // make 3 withdraw requests
        // resolve 1st fully, and 2nd partially
        // assert claimable and sharesProcessed for 1st and 2nd requests
        (uint256 sharesLeftToResolve,,) = _createPartialWithdrawWithResolution(requestType);

        (,, uint256 repayAmount,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        (uint256 withdrawAmount,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, address(superloop));

        // resolve 2nd fuly and 3rd partially. I will unwind the entire amount but claim only partial amount
        uint256 repayAmountWithPremium = repayAmount + (repayAmount * 1) / 10000;
        uint256 sharesToResolve = sharesLeftToResolve / 2;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _repayCall(XTZ, repayAmount);
        moduleExecutionData[1] = _withdrawCall(ST_XTZ, withdrawAmount);
        moduleExecutionData[2] =
            _swapCallExactOutCurve(ST_XTZ, XTZ, XTZ_STXTZ_POOL, withdrawAmount, repayAmountWithPremium, STXTZ_XTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(XTZ, repayAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveWithdrawRequestsCall(sharesToResolve, requestType, abi.encode(intermediateExecutionData));

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        DataTypes.WithdrawRequestData memory withdrawRequest2 = withdrawManager.withdrawRequest(2, requestType);
        DataTypes.WithdrawRequestData memory withdrawRequest3 = withdrawManager.withdrawRequest(3, requestType);
        uint256 resolutionIdPointer = withdrawManager.resolutionIdPointer(requestType);
        uint256 totalPendingWithdraws = withdrawManager.totalPendingWithdraws(requestType);

        assertTrue(withdrawRequest2.amountClaimable > 0);
        assertTrue(withdrawRequest2.sharesProcessed == withdrawRequest2.shares);
        assertTrue(withdrawRequest3.amountClaimable > 0);
        assertTrue(withdrawRequest3.sharesProcessed > 0 && withdrawRequest3.sharesProcessed < withdrawRequest3.shares);

        assertTrue(withdrawRequest2.state == DataTypes.RequestProcessingState.FULLY_PROCESSED);
        assertTrue(withdrawRequest3.state == DataTypes.RequestProcessingState.PARTIALLY_PROCESSED);

        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
        assertApproxEqAbs(exchangeRateAfter, exchangeRateBefore, 1000);
        assertEq(totalPendingWithdraws, sharesLeftToResolve - sharesToResolve);
        assertEq(resolutionIdPointer, 3);
    }

    function test_resolveWithdrawRequestsWithCancellation() public {
        (uint256 sharesLeftToResolve,,) = _createPartialWithdrawWithResolution(requestType);

        // shoud not be able to cancel withdraw request if it's already processed
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.INVALID_WITHDRAW_REQUEST_STATE));
        withdrawManager.cancelWithdrawRequest(1, requestType);
        vm.stopPrank();

        // req 2 is partially processed, hence it should be partially cancelled and user 2 should get back the remaining shares + claimable amount
        uint256 user2BalanceBefore = IERC20(XTZ).balanceOf(user2);
        uint256 user2ShareBalanceBefore = superloop.balanceOf(user2);
        vm.startPrank(user2);
        withdrawManager.cancelWithdrawRequest(2, requestType);
        vm.stopPrank();
        uint256 user2BalanceAfter = IERC20(XTZ).balanceOf(user2);
        uint256 user2ShareBalanceAfter = superloop.balanceOf(user2);

        DataTypes.WithdrawRequestData memory withdrawRequest2 = withdrawManager.withdrawRequest(2, requestType);
        assertEq(uint256(withdrawRequest2.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_CANCELLED));
        assertEq(
            user2ShareBalanceAfter - user2ShareBalanceBefore, withdrawRequest2.shares - withdrawRequest2.sharesProcessed
        );
        assertEq(withdrawRequest2.amountClaimable, 0);
        assertEq(withdrawRequest2.amountClaimed, user2BalanceAfter - user2BalanceBefore);
        uint256 totalPendingWithdraws = withdrawManager.totalPendingWithdraws(requestType);
        assertEq(totalPendingWithdraws, sharesLeftToResolve - withdrawRequest2.sharesProcessed);

        (,, uint256 repayAmount,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        (uint256 withdrawAmount,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, address(superloop));

        // unwind the remaining position
        uint256 repayAmountWithPremium = repayAmount + (repayAmount * 1) / 10000;
        uint256 sharesToResolve = totalPendingWithdraws;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _repayCall(XTZ, repayAmount);
        moduleExecutionData[1] = _withdrawCall(ST_XTZ, withdrawAmount);
        moduleExecutionData[2] =
            _swapCallExactOutCurve(ST_XTZ, XTZ, XTZ_STXTZ_POOL, withdrawAmount, repayAmountWithPremium, STXTZ_XTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(XTZ, repayAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveWithdrawRequestsCall(sharesToResolve, requestType, abi.encode(intermediateExecutionData));

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
        assertApproxEqAbs(exchangeRateAfter, exchangeRateBefore, 1000);

        // pending withdraws should be only worth 3rd request
        // 3rd request shoudl be resolved based on amount, ie. 2nd should get skipped
        uint256 resolutionIdPointer = withdrawManager.resolutionIdPointer(requestType);
        DataTypes.WithdrawRequestData memory withdrawRequest3 = withdrawManager.withdrawRequest(3, requestType);
        assertEq(uint256(withdrawRequest3.state), uint256(DataTypes.RequestProcessingState.FULLY_PROCESSED));
        assertEq(withdrawRequest3.sharesProcessed, withdrawRequest3.shares);
        assertTrue(withdrawRequest3.amountClaimable > 0);
        totalPendingWithdraws = withdrawManager.totalPendingWithdraws(requestType);
        assertEq(totalPendingWithdraws, 0);
        assertEq(resolutionIdPointer, 4);

        // new withdraw request should be able to be made, ie not blocked because of cancellation
        // user 2 shoudl be able to make a new withdraw request
        vm.startPrank(user2);
        superloop.approve(address(withdrawManager), 10 * ONE_SHARE);
        withdrawManager.requestWithdraw(10 * ONE_SHARE, requestType);
        vm.stopPrank();

        vm.startPrank(user3);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_UNCLAIMED));
        withdrawManager.requestWithdraw(10 * ONE_SHARE, requestType);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_UNCLAIMED));
        withdrawManager.requestWithdraw(10 * ONE_SHARE, requestType);
        vm.stopPrank();
    }

    function test_withdraw() public {
        _createPartialWithdrawWithResolution(requestType);

        // should be able to withdraw if fully processed
        uint256 user1BalanceBefore = IERC20(XTZ).balanceOf(user1);
        uint256 user1ShareBalanceBefore = superloop.balanceOf(user1);
        vm.startPrank(user1);
        withdrawManager.withdraw(requestType);
        vm.stopPrank();
        uint256 user1BalanceAfter = IERC20(XTZ).balanceOf(user1);
        uint256 user1ShareBalanceAfter = superloop.balanceOf(user1);
        DataTypes.WithdrawRequestData memory withdrawRequest1 = withdrawManager.withdrawRequest(1, requestType);
        assertEq(uint256(withdrawRequest1.state), uint256(DataTypes.RequestProcessingState.FULLY_PROCESSED));
        assertEq(withdrawRequest1.sharesProcessed, withdrawRequest1.shares);
        assertTrue(withdrawRequest1.amountClaimable == 0);
        assertEq(withdrawRequest1.amountClaimed, user1BalanceAfter - user1BalanceBefore);
        assertEq(user1ShareBalanceAfter - user1ShareBalanceBefore, 0);

        // should not be able to claim if already claimed
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_ALREADY_CLAIMED));
        withdrawManager.withdraw(requestType);
        vm.stopPrank();

        // should be able to withdraw partially processed
        uint256 user2BalanceBefore = IERC20(XTZ).balanceOf(user2);
        uint256 user2ShareBalanceBefore = superloop.balanceOf(user2);
        vm.startPrank(user2);
        withdrawManager.withdraw(requestType);
        vm.stopPrank();
        uint256 user2BalanceAfter = IERC20(XTZ).balanceOf(user2);
        uint256 user2ShareBalanceAfter = superloop.balanceOf(user2);
        DataTypes.WithdrawRequestData memory withdrawRequest2 = withdrawManager.withdrawRequest(2, requestType);
        assertEq(uint256(withdrawRequest2.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_PROCESSED));
        assertTrue(withdrawRequest2.amountClaimable == 0);
        assertEq(withdrawRequest2.amountClaimed, user2BalanceAfter - user2BalanceBefore);
        assertEq(user2ShareBalanceAfter - user2ShareBalanceBefore, 0);

        // should not be able to claim if nothing left to claim
        vm.startPrank(user2);
        vm.expectRevert(bytes(Errors.CANNOT_CLAIM_ZERO_AMOUNT));
        withdrawManager.withdraw(requestType);
        vm.stopPrank();

        // should not be able to claim if cancelled
        user2BalanceBefore = IERC20(XTZ).balanceOf(user2);
        user2ShareBalanceBefore = superloop.balanceOf(user2);
        vm.startPrank(user2);
        withdrawManager.cancelWithdrawRequest(2, requestType);
        withdrawRequest2 = withdrawManager.withdrawRequest(2, requestType);
        assertEq(uint256(withdrawRequest2.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_CANCELLED));
        assertEq(withdrawRequest2.amountClaimable, 0);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_NOT_FOUND));
        withdrawManager.withdraw(requestType);
        vm.stopPrank();
        user2BalanceAfter = IERC20(XTZ).balanceOf(user2);
        user2ShareBalanceAfter = superloop.balanceOf(user2);
        assertEq(user2BalanceAfter - user2BalanceBefore, 0);
        assertEq(
            user2ShareBalanceAfter - user2ShareBalanceBefore, withdrawRequest2.shares - withdrawRequest2.sharesProcessed
        );

        // should not be able to claim if unprocessed
        vm.startPrank(user3);
        vm.expectRevert(bytes(Errors.WITHDRAW_REQUEST_ACTIVE));
        withdrawManager.withdraw(requestType);
        vm.stopPrank();
    }

    function test_isolationOfQueues() public {
        if (requestType != DataTypes.WithdrawRequestType.GENERAL) return;

        _createPartialDepositWithResolution(true);

        // make a withdraw request by every user on every queue
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user1, DataTypes.WithdrawRequestType.GENERAL);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user2, DataTypes.WithdrawRequestType.GENERAL);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user3, DataTypes.WithdrawRequestType.GENERAL);

        _makeWithdrawRequest(address(superloop), ONE_SHARE, user1, DataTypes.WithdrawRequestType.DEFERRED);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user2, DataTypes.WithdrawRequestType.DEFERRED);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user3, DataTypes.WithdrawRequestType.DEFERRED);

        _makeWithdrawRequest(address(superloop), ONE_SHARE, user1, DataTypes.WithdrawRequestType.PRIORITY);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user2, DataTypes.WithdrawRequestType.PRIORITY);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user3, DataTypes.WithdrawRequestType.PRIORITY);

        _makeWithdrawRequest(address(superloop), ONE_SHARE, user1, DataTypes.WithdrawRequestType.INSTANT);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user2, DataTypes.WithdrawRequestType.INSTANT);
        _makeWithdrawRequest(address(superloop), ONE_SHARE, user3, DataTypes.WithdrawRequestType.INSTANT);

        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        DataTypes.WithdrawRequestData[] memory withdrawRequestsGeneral =
            withdrawManager.withdrawRequests(ids, DataTypes.WithdrawRequestType.GENERAL);
        DataTypes.WithdrawRequestData[] memory withdrawRequestsDeferred =
            withdrawManager.withdrawRequests(ids, DataTypes.WithdrawRequestType.DEFERRED);
        DataTypes.WithdrawRequestData[] memory withdrawRequestsPriority =
            withdrawManager.withdrawRequests(ids, DataTypes.WithdrawRequestType.PRIORITY);
        DataTypes.WithdrawRequestData[] memory withdrawRequestsInstant =
            withdrawManager.withdrawRequests(ids, DataTypes.WithdrawRequestType.INSTANT);

        assertEq(withdrawRequestsGeneral.length, 3);
        assertEq(withdrawRequestsDeferred.length, 3);
        assertEq(withdrawRequestsPriority.length, 3);
        assertEq(withdrawRequestsInstant.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(withdrawRequestsGeneral[i].user, users[i]);
            assertEq(withdrawRequestsDeferred[i].user, users[i]);
            assertEq(withdrawRequestsPriority[i].user, users[i]);

            assertEq(withdrawRequestsInstant[i].shares, ONE_SHARE);
            assertEq(withdrawRequestsDeferred[i].shares, ONE_SHARE);
            assertEq(withdrawRequestsPriority[i].shares, ONE_SHARE);
            assertEq(withdrawRequestsGeneral[i].shares, ONE_SHARE);
        }

        uint256 totalPendingWithdraws = withdrawManager.totalPendingWithdraws(DataTypes.WithdrawRequestType.GENERAL);
        assertEq(totalPendingWithdraws, 3 * ONE_SHARE);
        totalPendingWithdraws = withdrawManager.totalPendingWithdraws(DataTypes.WithdrawRequestType.DEFERRED);
        assertEq(totalPendingWithdraws, 3 * ONE_SHARE);
        totalPendingWithdraws = withdrawManager.totalPendingWithdraws(DataTypes.WithdrawRequestType.PRIORITY);
        assertEq(totalPendingWithdraws, 3 * ONE_SHARE);
        totalPendingWithdraws = withdrawManager.totalPendingWithdraws(DataTypes.WithdrawRequestType.INSTANT);
        assertEq(totalPendingWithdraws, 3 * ONE_SHARE);
    }

    function _resolveAllRequests(uint256 sharesToResolve, DataTypes.WithdrawRequestType _requestType) internal {
        (,, uint256 repayAmount,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        (uint256 withdrawAmount,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, address(superloop));
        uint256 repayAmountWithPremium = repayAmount + (repayAmount * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _repayCall(XTZ, repayAmount);
        moduleExecutionData[1] = _withdrawCall(ST_XTZ, withdrawAmount);
        moduleExecutionData[2] =
            _swapCallExactOutCurve(ST_XTZ, XTZ, XTZ_STXTZ_POOL, withdrawAmount, repayAmountWithPremium, STXTZ_XTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(XTZ, repayAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveWithdrawRequestsCall(sharesToResolve, _requestType, abi.encode(intermediateExecutionData));

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        // withdraw requests should have claimable > 0 and sharesProcessed > 0, exchange rate remains the same
        DataTypes.WithdrawRequestData memory withdrawRequest1 = withdrawManager.withdrawRequest(1, _requestType);
        DataTypes.WithdrawRequestData memory withdrawRequest2 = withdrawManager.withdrawRequest(2, _requestType);
        DataTypes.WithdrawRequestData memory withdrawRequest3 = withdrawManager.withdrawRequest(3, _requestType);
        uint256 resolutionIdPointer = withdrawManager.resolutionIdPointer(_requestType);
        uint256 totalPendingWithdraws = withdrawManager.totalPendingWithdraws(_requestType);

        assertTrue(withdrawRequest1.amountClaimable > 0);
        assertTrue(withdrawRequest1.sharesProcessed == withdrawRequest1.shares);
        assertTrue(withdrawRequest2.amountClaimable > 0);
        assertTrue(withdrawRequest2.sharesProcessed == withdrawRequest2.shares);
        assertTrue(withdrawRequest3.amountClaimable > 0);
        assertTrue(withdrawRequest3.sharesProcessed == withdrawRequest3.shares);
        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
        assertApproxEqAbs(exchangeRateAfter, exchangeRateBefore, 1000);
        assertEq(totalPendingWithdraws, 0);
        assertEq(resolutionIdPointer, 4);
    }
}
