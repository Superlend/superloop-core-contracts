// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "../IntegrationBase.sol";
import {DataTypes} from "../../../../src/common/DataTypes.sol";
import {console} from "forge-std/console.sol";

contract WithdrawManagerTest is IntegrationBase {
    bool depositAll = true;

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
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.GENERAL), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.INSTANT), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.PRIORITY), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.DEFERRED), 1);
    }

    // function test_resolveWithdrawRequests() public {
    //     (uint256 supplyAmountUnscaled, uint256 borrowAmountUnscaled) = _createPartialDepositWithResolution(depositAll);

    //     // make 3 withdraw requests
    //     uint256 user1ShareBalance = superloop.balanceOf(user1);
    //     uint256 user2ShareBalance = superloop.balanceOf(user2);
    //     uint256 user3ShareBalance = superloop.balanceOf(user3);
    //     _makeWithdrawRequest(address(superloop), user1ShareBalance, user1, DataTypes.WithdrawRequestType.GENERAL);
    //     _makeWithdrawRequest(address(superloop), user2ShareBalance, user2, DataTypes.WithdrawRequestType.GENERAL);
    //     _makeWithdrawRequest(address(superloop), user3ShareBalance, user3, DataTypes.WithdrawRequestType.GENERAL);

    //     _resolveAllRequests(user1ShareBalance + user2ShareBalance + user3ShareBalance);
    // }

    function test_resolveWithdrawRequestsWithPartials() public {
        _createPartialWithdrawWithResolution();

        // make 3 withdraw requests
        // resolve 1st fully, and 2nd partially
        // assert claimable and sharesProcessed for 1st and 2nd requests
        // resolve 2nd fuly and 3rd partially
        // assert claimable and sharesProcessed for 2nd and 3rd requests
    }

    // function test_resolveWithdrawRequestsWithCancellation() public {
    //     // shoud not bel able to cancel withdraw request if it's already processed
    //     // req 2 is partially processed, hence it should be partially cancelled and user 2 should get back the remaining shares + claimable amount
    //     // pending withdraws should be only worth 3rd request
    //     // 3rd request shoudl be resolved based on amount, ie. 2nd should get skipped
    //     // new withdraw request should be able to be made, ie not blocked because of cancellation
    // }

    // function test_withdraw() public {
    //     // should be able to withdraw if fully processed
    //     // should not be able to claim if nothing left to claim
    //     // should not be able to claim if cancelled
    //     // should not be able to claim if unprocessed
    // }

    // function test_partialWithdraw() public {
    //     // withdraw when only half of the request has been fulfilled
    //     // assert claimable and sharesProcessed for the request
    //     // resolve the request
    //     // assert claimable and sharesProcessed for the request
    // }

    function _resolveAllRequests(uint256 sharesToResolve) internal {
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
        finalExecutionData[0] = _resolveWithdrawRequestsCall(
            sharesToResolve, DataTypes.WithdrawRequestType.GENERAL, abi.encode(intermediateExecutionData)
        );

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        // withdraw requests should have claimable > 0 and sharesProcessed > 0, exchange rate remains the same
        DataTypes.WithdrawRequestData memory withdrawRequest1 =
            withdrawManager.withdrawRequest(1, DataTypes.WithdrawRequestType.GENERAL);
        DataTypes.WithdrawRequestData memory withdrawRequest2 =
            withdrawManager.withdrawRequest(2, DataTypes.WithdrawRequestType.GENERAL);
        DataTypes.WithdrawRequestData memory withdrawRequest3 =
            withdrawManager.withdrawRequest(3, DataTypes.WithdrawRequestType.GENERAL);
        uint256 resolutionIdPointer = withdrawManager.resolutionIdPointer(DataTypes.WithdrawRequestType.GENERAL);
        uint256 totalPendingWithdraws = withdrawManager.totalPendingWithdraws(DataTypes.WithdrawRequestType.GENERAL);

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
