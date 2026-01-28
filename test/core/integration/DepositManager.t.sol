// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DepositManager} from "../../../src/core/DepositManager/DepositManager.sol";
import {console} from "forge-std/Test.sol";
import {Errors} from "../../../src/common/Errors.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DepositManagerTest is IntegrationBase {
    bool depositAll = false;
    DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.GENERAL;

    function setUp() public override {
        super.setUp();

        DataTypes.AaveV3EmodeParams memory params =
            DataTypes.AaveV3EmodeParams({emodeCategory: environment.emodeCategory});

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
        assertEq(depositManager.vault(), address(superloop));
        assertEq(depositManager.asset(), environment.vaultAsset);
        assertEq(depositManager.nextDepositRequestId(), 1);
    }

    function test_requestDeposit_MinimumDepositAmountNotMet() public {
        uint256 depositAmount = 99;

        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }

    function test_resolveDepositRequestResolution() public {
        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);
        uint256 depositAmount = 100 * 10 ** environment.vaultAssetDecimals;
        _makeDepositRequest(depositAmount, user1, true);

        // build the operate call
        uint256 supplyAmount = 150 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(); // USDe supply
        uint256 borrowAmount = 60 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(); // USDC borrow
        uint256 flashLoanAmount = supplyAmount - depositAmount;
        uint256 swapAmount = borrowAmount + depositAmount;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _supplyCall(environment.lendAssets[0], supplyAmount);
        moduleExecutionData[1] = _borrowCall(environment.borrowAssets[0], borrowAmount);

        moduleExecutionData[2] = USE_MORPHO
            ? _swapCallExactOut(
                environment.borrowAssets[0],
                environment.lendAssets[0],
                borrowAmount,
                flashLoanAmount,
                environment.router,
                USDC_USDE_POOL_FEE,
                block.timestamp + 100
            )
            : _swapCallExactOutCurve(XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmount, supplyAmountWithPremium, XTZ_STXTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = USE_MORPHO
            ? _morphoFlashloanCall(environment.lendAssets[0], flashLoanAmount, abi.encode(moduleExecutionData))
            : _flashloanCall(environment.lendAssets[0], supplyAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveDepositRequestsCall(environment.vaultAsset, depositAmount, abi.encode(intermediateExecutionData));

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        // user 1 should get shares
        DataTypes.DepositRequestData memory depositRequest1 = depositManager.depositRequest(1);
        uint256 user1Shares = superloop.balanceOf(user1);
        assertEq(user1Shares, depositRequest1.sharesMinted);

        // deposit maanger should not have any xtz now, resolution ptr must have increased, pendingDepsotAmout should be 0
        assertEq(IERC20(environment.vaultAsset).balanceOf(address(depositManager)), 0);
        assertEq(depositManager.totalPendingDeposits(), 0);
        assertEq(depositManager.resolutionIdPointer(), 2);

        // exchange rate before should equal to exchange rate after
        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
        assertTrue(
            exchangeRateAfter > exchangeRateBefore
                ? exchangeRateAfter - exchangeRateBefore < 100
                : exchangeRateBefore - exchangeRateAfter < 100
        );
    }

    function test_instantDepositWithLimit() public {
        _createPartialDepositWithResolution(depositAll);

        // i should be able to do an instant deposit of 0.001 xtz
        uint256 scale = 10 ** environment.vaultAssetDecimals;
        uint256 user1SharesBalanceBefore = superloop.balanceOf(user1);
        deal(environment.vaultAsset, user1, scale);
        vm.startPrank(user1);
        IERC20(environment.vaultAsset).approve(address(superloop), scale);
        superloop.deposit(scale / 1000, user1);
        uint256 user1SharesBalanceAfter = superloop.balanceOf(user1);

        assertTrue(user1SharesBalanceAfter > user1SharesBalanceBefore);

        // i should not be able to do an instant deposit of 100 xtz due to cash reserve
        deal(environment.vaultAsset, user1, 100 * scale);
        vm.startPrank(user1);
        IERC20(environment.vaultAsset).approve(address(superloop), 100 * scale);
        vm.expectRevert(bytes(Errors.INSUFFICIENT_CASH_SHORTFALL));
        superloop.deposit(100 * scale, user1);
        vm.stopPrank();
    }

    function test_resolveDepositRequestWithPartials() public {
        _createPartialDepositWithResolution(depositAll); // 300 worth of depostits, 150 pending

        // try to operate again
        uint256 vaultTokenScale = 10 ** environment.vaultAssetDecimals;
        uint256 lendTokenScale = 10 ** IERC20Metadata(environment.lendAssets[0]).decimals();
        uint256 borrowTokenScale = 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals();

        uint256 depositAmount_secondBatch = 90 * vaultTokenScale;
        uint256 supplyAmount = 180 * lendTokenScale;
        uint256 borrowAmount = 110 * borrowTokenScale;
        uint256 swapAmount = borrowAmount + depositAmount_secondBatch;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

        uint256 flashLoanAmount = supplyAmount - depositAmount_secondBatch;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _supplyCall(environment.lendAssets[0], supplyAmount);
        moduleExecutionData[1] = _borrowCall(environment.borrowAssets[0], borrowAmount);

        moduleExecutionData[2] = USE_MORPHO
            ? _swapCallExactOut(
                environment.borrowAssets[0],
                environment.lendAssets[0],
                borrowAmount,
                flashLoanAmount,
                environment.router,
                USDC_USDE_POOL_FEE,
                block.timestamp + 100
            )
            : _swapCallExactOutCurve(XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmount, supplyAmountWithPremium, XTZ_STXTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = USE_MORPHO
            ? _morphoFlashloanCall(environment.lendAssets[0], flashLoanAmount, abi.encode(moduleExecutionData))
            : _flashloanCall(environment.lendAssets[0], supplyAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] = _resolveDepositRequestsCall(
            environment.vaultAsset, depositAmount_secondBatch, abi.encode(intermediateExecutionData)
        );

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);
        DataTypes.DepositRequestData memory depositRequest2_before = depositManager.depositRequest(2);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);
        DataTypes.DepositRequestData memory depositRequest2_after = depositManager.depositRequest(2);

        assertApproxEqAbs(exchangeRateBefore, exchangeRateAfter, 1000); // 1000 is the precision

        assertTrue(depositRequest2_after.sharesMinted > depositRequest2_before.sharesMinted);
        // deposit request 2 should be fully processed, deposit request 3 should be partially processed
        assertTrue(superloop.balanceOf(user3) > 0);

        // pending deposits should be 150 xtz
        assertEq(depositManager.totalPendingDeposits(), 60 * vaultTokenScale);

        // resolution id pointer should be 2
        assertEq(depositManager.resolutionIdPointer(), 3);

        // deposit request 2 should be partially processed
        DataTypes.DepositRequestData memory depositRequest3 = depositManager.depositRequest(3);
        assertEq(uint256(depositRequest3.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_PROCESSED));
        assertEq(depositRequest3.amountProcessed, 40 * vaultTokenScale);

        // deposit another batch, with 60 xtz resolving a request partially

        uint256 depositAmount_thirdBatch = 60 * vaultTokenScale;
        uint256 supplyAmountSecondBatch = 120 * lendTokenScale;
        uint256 borrowAmountSecondBatch = 75 * borrowTokenScale;
        uint256 swapAmountSecondBatch = borrowAmountSecondBatch + depositAmount_thirdBatch;
        uint256 supplyAmountWithPremiumSecondBatch = supplyAmountSecondBatch + (supplyAmountSecondBatch * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionDataSecondBatch = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionDataSecondBatch[0] = _supplyCall(environment.lendAssets[0], supplyAmountSecondBatch);
        moduleExecutionDataSecondBatch[1] = _borrowCall(environment.borrowAssets[0], borrowAmountSecondBatch);

        uint256 flashLoanAmountSecondBatch = supplyAmountSecondBatch - depositAmount_thirdBatch;

        moduleExecutionDataSecondBatch[2] = USE_MORPHO
            ? _swapCallExactOut(
                environment.borrowAssets[0],
                environment.lendAssets[0],
                borrowAmountSecondBatch,
                flashLoanAmountSecondBatch,
                environment.router,
                USDC_USDE_POOL_FEE,
                block.timestamp + 100
            )
            : _swapCallExactOutCurve(
                XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmountSecondBatch, supplyAmountWithPremiumSecondBatch, XTZ_STXTZ_SWAP
            );

        DataTypes.ModuleExecutionData[] memory intermediateExecutionDataSecondBatch =
            new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionDataSecondBatch[0] = USE_MORPHO
            ? _morphoFlashloanCall(environment.lendAssets[0], flashLoanAmount, abi.encode(moduleExecutionDataSecondBatch))
            : _flashloanCall(environment.lendAssets[0], supplyAmountSecondBatch, abi.encode(moduleExecutionDataSecondBatch));

        DataTypes.ModuleExecutionData[] memory finalExecutionDataSecondBatch = new DataTypes.ModuleExecutionData[](1);
        finalExecutionDataSecondBatch[0] = _resolveDepositRequestsCall(
            environment.lendAssets[0], depositAmount_thirdBatch, abi.encode(intermediateExecutionDataSecondBatch)
        );

        uint256 exchangeRateBeforeSecondBatch = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionDataSecondBatch);

        uint256 exchangeRateAfterSecondBatch = superloop.convertToAssets(ONE_SHARE);

        assertApproxEqAbs(exchangeRateBeforeSecondBatch, exchangeRateAfterSecondBatch, 1000);

        // pending deposits should be 150 xtz
        assertEq(depositManager.totalPendingDeposits(), 0);

        // resolution id pointer should be 2
        assertEq(depositManager.resolutionIdPointer(), 4);

        depositRequest3 = depositManager.depositRequest(3);
        assertEq(uint256(depositRequest3.state), uint256(DataTypes.RequestProcessingState.FULLY_PROCESSED));
    }

    function test_resolveDepositRequestWithCancellation() public {
        uint256 vaultTokenScale = 10 ** IERC20Metadata(environment.vaultAsset).decimals();
        uint256 lendTokenScale = 10 ** IERC20Metadata(environment.lendAssets[0]).decimals();
        uint256 borrowTokenScale = 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals();

        _createPartialDepositWithResolution(depositAll); // 300 worth of depostits, 150 pending

        // user1 should not be able to cancel deposit request 1 because it's already processed
        vm.startPrank(user1);
        vm.expectRevert(bytes(Errors.DEPOSIT_REQUEST_ALREADY_PROCESSED));
        depositManager.cancelDepositRequest(1);
        vm.stopPrank();

        // cancel deposit request 2 => it should be partially cancelled and user 2 should get back the remaining amount
        uint256 user2BalanceBefore = IERC20(environment.vaultAsset).balanceOf(user2);
        vm.startPrank(user2);
        depositManager.cancelDepositRequest(2);
        vm.stopPrank();
        // user 2 should get back the remaining amount
        uint256 user2BalanceAfter = IERC20(environment.vaultAsset).balanceOf(user2);
        assertEq(user2BalanceAfter - user2BalanceBefore, 50 * vaultTokenScale);
        // deposit request 2 should be partially cancelled
        DataTypes.DepositRequestData memory depositRequest = depositManager.depositRequest(2);
        assertEq(uint256(depositRequest.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_CANCELLED));
        assertEq(depositRequest.amountProcessed, 50 * vaultTokenScale);

        // pending deposits should be 100 xtz
        assertEq(depositManager.totalPendingDeposits(), 100 * vaultTokenScale);

        // try to operate again with 75 xtz => request 3 should be partially processed
        uint256 depositAmount_secondBatch = 75 * vaultTokenScale;
        uint256 supplyAmount = 150 * lendTokenScale;
        uint256 borrowAmount = 85 * borrowTokenScale;
        uint256 swapAmount = borrowAmount + depositAmount_secondBatch;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _supplyCall(environment.lendAssets[0], supplyAmount);
        moduleExecutionData[1] = _borrowCall(environment.borrowAssets[0], borrowAmount);
        uint256 flashLoanAmount = supplyAmount - depositAmount_secondBatch;

        moduleExecutionData[2] = USE_MORPHO
            ? _swapCallExactOut(
                environment.borrowAssets[0],
                environment.lendAssets[0],
                borrowAmount,
                flashLoanAmount,
                environment.router,
                USDC_USDE_POOL_FEE,
                block.timestamp + 100
            )
            : _swapCallExactOutCurve(
                environment.borrowAssets[0],
                environment.lendAssets[0],
                XTZ_STXTZ_POOL,
                swapAmount,
                supplyAmountWithPremium,
                XTZ_STXTZ_SWAP
            );

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = USE_MORPHO
            ? _morphoFlashloanCall(environment.lendAssets[0], flashLoanAmount, abi.encode(moduleExecutionData))
            : _flashloanCall(environment.lendAssets[0], supplyAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] = _resolveDepositRequestsCall(
            environment.vaultAsset, depositAmount_secondBatch, abi.encode(intermediateExecutionData)
        );

        uint256 exchangeRateBefore = superloop.convertToAssets(ONE_SHARE);

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        uint256 exchangeRateAfter = superloop.convertToAssets(ONE_SHARE);

        assertApproxEqAbs(exchangeRateBefore, exchangeRateAfter, 1000); // 1000 is the precision

        // pending deposit should be 25
        assertEq(depositManager.totalPendingDeposits(), 25 * XTZ_SCALE);
        // resolution id pointer should be 3
        assertEq(depositManager.resolutionIdPointer(), 3);

        // deposit request 3 should be partially processed
        DataTypes.DepositRequestData memory depositRequest3 = depositManager.depositRequest(3);
        assertEq(uint256(depositRequest3.state), uint256(DataTypes.RequestProcessingState.PARTIALLY_PROCESSED));
        assertEq(depositRequest3.amountProcessed, 75 * XTZ_SCALE);

        // user3 should get shares
        assertTrue(superloop.balanceOf(user3) > 0);

        //////////////// Make sure new deposits are working as expected ////////////////

        // user1 and user2 should be able to request new deposits
        _makeDepositRequest(100 * vaultTokenScale, user1, true);
        _makeDepositRequest(100 * vaultTokenScale, user2, true);

        // user3 should not be able to request new deposits because one request is still under process
        vm.expectRevert(bytes(Errors.DEPOSIT_REQUEST_ACTIVE));
        vm.startPrank(user3);
        depositManager.requestDeposit(100 * vaultTokenScale, address(0));
        vm.stopPrank();
    }
}
