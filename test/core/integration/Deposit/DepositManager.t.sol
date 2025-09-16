// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "../IntegrationBase.sol";
import {DataTypes} from "../../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DepositManager} from "../../../../src/core/DepositManager/DepositManager.sol";
import {console} from "forge-std/Test.sol";
import {Errors} from "../../../../src/common/Errors.sol";

contract DepositManagerTest is IntegrationBase {
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

    function test_initialize() public {
        assertEq(depositManager.vault(), address(superloop));
        assertEq(depositManager.asset(), XTZ);
        assertEq(depositManager.nextDepositRequestId(), 1);
    }

    // function test_resolveDepositRequestResolution() public {
    //     uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);
    //     uint256 depositAmount = 100 * XTZ_SCALE;
    //     _makeDepositRequest(depositAmount, user1, true);

    //     // // build the operate call
    //     uint256 supplyAmount = 150 * STXTZ_SCALE;
    //     uint256 borrowAmount = 60 * XTZ_SCALE;
    //     uint256 swapAmount = borrowAmount + depositAmount;
    //     uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

    //     DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
    //     moduleExecutionData[0] = _supplyCall(ST_XTZ, supplyAmount);
    //     moduleExecutionData[1] = _borrowCall(XTZ, borrowAmount);

    //     moduleExecutionData[2] =
    //         _swapCallExactOutCurve(XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmount, supplyAmountWithPremium, XTZ_STXTZ_SWAP);

    //     DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
    //     intermediateExecutionData[0] = _flashloanCall(ST_XTZ, supplyAmount, abi.encode(moduleExecutionData));

    //     DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
    //     finalExecutionData[0] = _resolveDepositRequestsCall(XTZ, depositAmount, abi.encode(intermediateExecutionData));

    //     vm.prank(admin);
    //     superloop.operate(finalExecutionData);

    //     // user 1 should get shares
    //     uint256 user1Shares = superloop.balanceOf(user1);
    //     assertTrue(user1Shares > 0);

    //     // deposit maanger should not have any xtz now, resolution ptr must have increased, pendingDepsotAmout should be 0
    //     assertEq(IERC20(XTZ).balanceOf(address(depositManager)), 0);
    //     assertEq(depositManager.totalPendingDeposits(), 0);
    //     assertEq(depositManager.resolutionIdPointer(), 2);

    //     // exchange rate before should equal to exchange rate after
    //     uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
    //     assertTrue(exchangeRateAfter > exchangeRateBefore ? exchangeRateAfter - exchangeRateBefore < 100 : exchangeRateBefore - exchangeRateAfter < 100);
    // }

    // function test_instantDepositWithLimit() public {
    //     _createPartialDepositWithResolution();

    //     // i should be able to do an instant deposit of 0.001 xtz
    //     uint256 user1SharesBalanceBefore = superloop.balanceOf(user1);
    //     deal(XTZ, user1, XTZ_SCALE);
    //     vm.startPrank(user1);
    //     IERC20(XTZ).approve(address(superloop), XTZ_SCALE);
    //     superloop.deposit(XTZ_SCALE/1000, user1);
    //     uint256 user1SharesBalanceAfter = superloop.balanceOf(user1);

    //     assertTrue(user1SharesBalanceAfter > user1SharesBalanceBefore);

    //     // i should not be able to do an instant deposit of 100 xtz due to cash reserve 
    //     deal(XTZ, user1, 100 * XTZ_SCALE);
    //     vm.startPrank(user1);
    //     IERC20(XTZ).approve(address(superloop), 100 * XTZ_SCALE);
    //     vm.expectRevert(bytes(Errors.INSUFFICIENT_CASH_SHORTFALL));
    //     superloop.deposit(100 * XTZ_SCALE, user1);
    //     vm.stopPrank();
    // }

    function test_resolveDepositRequestWithPartials() public {
        _createPartialDepositWithResolution();

        // try to operate again 

        uint256 depositAmount_firstBatch = 100 * XTZ_SCALE;
        uint256 supplyAmount = 200 * STXTZ_SCALE;
        uint256 borrowAmount = 110 * XTZ_SCALE;
        uint256 swapAmount = borrowAmount + depositAmount_firstBatch;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _supplyCall(ST_XTZ, supplyAmount);
        moduleExecutionData[1] = _borrowCall(XTZ, borrowAmount);

        moduleExecutionData[2] =
            _swapCallExactOutCurve(XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmount, supplyAmountWithPremium, XTZ_STXTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(ST_XTZ, supplyAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveDepositRequestsCall(XTZ, depositAmount_firstBatch, abi.encode(intermediateExecutionData));

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
    }

    // function test_resolveDepositRequestWithCancellation() public {}

    function _makeDepositRequest(uint256 depositAmount, address user, bool _deal) public {
        if (_deal) {
            deal(XTZ, user, depositAmount);
        }

        vm.startPrank(user);
        IERC20(XTZ).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }

    function _createPartialDepositWithResolution() public {
        uint256 depositAmount = 100 * XTZ_SCALE;
        _makeDepositRequest(depositAmount, user1, true);
        _makeDepositRequest(depositAmount, user2, true);
        _makeDepositRequest(depositAmount, user3, true);

        uint256 depositAmount_firstBatch = (3 * depositAmount) / 2;
        // build the operate call
        uint256 supplyAmount = 250 * STXTZ_SCALE;
        uint256 borrowAmount = 120 * XTZ_SCALE;
        uint256 swapAmount = borrowAmount + depositAmount_firstBatch;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _supplyCall(ST_XTZ, supplyAmount);
        moduleExecutionData[1] = _borrowCall(XTZ, borrowAmount);

        moduleExecutionData[2] =
            _swapCallExactOutCurve(XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmount, supplyAmountWithPremium, XTZ_STXTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(ST_XTZ, supplyAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveDepositRequestsCall(XTZ, depositAmount_firstBatch, abi.encode(intermediateExecutionData));

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        // user 1 and user user 2 should get shares
        // user 3 should not get shares
        assertTrue(superloop.balanceOf(user1) > 0);
        assertTrue(superloop.balanceOf(user2) > 0);
        assertTrue(superloop.balanceOf(user3) == 0);

        // deposit manager should have 150 xtz now
        assertEq(IERC20(XTZ).balanceOf(address(depositManager)), 150 * XTZ_SCALE);
        // pending deposits should be 150 xtz
        assertEq(depositManager.totalPendingDeposits(), 150 * XTZ_SCALE);

        // resolution id pointer should be 2
        assertEq(depositManager.resolutionIdPointer(), 2);

        // deposit request 2 should be partially processed
        DataTypes.DepositRequestData memory depositRequest2 = depositManager.depositRequest(2);
        assertEq(uint256(depositRequest2.state), uint256(DataTypes.DepositRequestProcessingState.PARTIALLY_PROCESSED));
        assertEq(depositRequest2.amountProcessed, 50 * XTZ_SCALE);

        // exchange rate before should equal to exchange rate after
        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
        assertTrue(
            exchangeRateAfter > exchangeRateBefore
                ? exchangeRateAfter - exchangeRateBefore < 100
                : exchangeRateBefore - exchangeRateAfter < 100
        );
    }
}
