// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IRouter} from "../../../src/mock/MockIRouter.sol";
import {IPriceOracleGetter} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";

contract WithdrawTest is IntegrationBase {
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

    function test_withdrawInstant() public {
        _initialDeposit();
        _initialRebalance();

        uint256 xtzBalance = IERC20(XTZ).balanceOf(address(superloop));
        uint256 user1ShareBalance = superloop.balanceOf(user1);
        uint256 user1BalanceBefore = IERC20(XTZ).balanceOf(address(user1));

        // lets say user1 wants to withdraw 0.3 shares
        uint256 redeemAmount = superloop.previewRedeem(3 * XTZ_SCALE * 10);

        // check if superloop has enough balance
        assertLt(redeemAmount, xtzBalance);

        // if yes, then do the instant withdrawal
        vm.prank(user1);
        superloop.redeem(3 * XTZ_SCALE * 10, user1, address(user1));

        // check if user1 has the balance
        uint256 user1BalanceAfter = IERC20(XTZ).balanceOf(address(user1));
        uint256 user1ShareBalanceAfter = superloop.balanceOf(user1);

        assertGt(user1BalanceAfter, user1BalanceBefore);
        assertLt(user1ShareBalanceAfter, user1ShareBalance);
    }

    function test_withdrawRequest() public {
        _initialDeposit();
        _initialRebalance();

        vm.startPrank(user1);
        // lets say user want to redeem 0.5 shares
        // make a withdraw request for this
        uint256 shares = 5 * XTZ_SCALE * 10;
        superloop.approve(address(withdrawManagerLegacy), shares);
        withdrawManagerLegacy.requestWithdraw(shares);
        vm.stopPrank();

        // check if the withdraw request is marked on the withdraw manager
        DataTypes.WithdrawRequestDataLegacy memory withdrawRequest =
            withdrawManagerLegacy.withdrawRequest(withdrawManagerLegacy.nextWithdrawRequestId() - 1);

        assertEq(withdrawRequest.shares, shares);
        assertEq(withdrawRequest.user, user1);

        // make the funds avaialble for withdrawal
        // deverage to enable withdraw of the amount
        // currently have 7stxtz in collat, 6xtz in borrow and 0.6 xtz in balance
        // repay 2stxtz and keep it as swapped for withdraw

        // mark this on the withdraw manager

        uint256 repayAmount = (19 * XTZ_SCALE) / 10; // ideally this should be more than 2, set to 1.9 becuase iguana dex has incorrect price
        uint256 withdrawAmount = 2 * STXTZ_SCALE;
        uint256 repayAmountWithPremium = repayAmount + (repayAmount * 5) / 10000; // 5 bps premium

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _repayCall(XTZ, repayAmount);

        moduleExecutionData[1] = _withdrawCall(ST_XTZ, withdrawAmount);

        moduleExecutionData[2] =
            _swapCallExactIn(ST_XTZ, XTZ, withdrawAmount, repayAmountWithPremium, ROUTER, XTZ_STXTZ_POOL_FEE);

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](2);
        finalExecutionData[0] = _flashloanCall(XTZ, repayAmount, abi.encode(moduleExecutionData));

        uint256 withdrawRequestId = withdrawManagerLegacy.nextWithdrawRequestId() - 1;
        finalExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.CALL,
            module: address(withdrawManagerLegacy),
            data: abi.encodeWithSelector(withdrawManagerLegacy.resolveWithdrawRequests.selector, withdrawRequestId)
        });

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        uint256 xtzBalanceOfWithdrawManager = IERC20(XTZ).balanceOf(address(withdrawManagerLegacy));
        uint256 shareBalanceOfWithdrawManager = superloop.balanceOf(address(withdrawManagerLegacy));

        DataTypes.WithdrawRequestDataLegacy memory _withdrawRequest =
            withdrawManagerLegacy.withdrawRequest(withdrawRequestId);

        DataTypes.WithdrawRequestStateLegacy state = withdrawManagerLegacy.getWithdrawRequestState(withdrawRequestId);

        assertTrue(xtzBalanceOfWithdrawManager > 0);
        assertTrue(shareBalanceOfWithdrawManager == 0);
        assertTrue(state == DataTypes.WithdrawRequestStateLegacy.CLAIMABLE);
        assertTrue(_withdrawRequest.claimed == false);
        assertTrue(_withdrawRequest.amount > 0);

        uint256 user1BalanceBefore = IERC20(XTZ).balanceOf(address(user1));
        vm.prank(user1);
        withdrawManagerLegacy.withdraw();

        _withdrawRequest = withdrawManagerLegacy.withdrawRequest(withdrawRequestId);
        uint256 user1BalanceAfter = IERC20(XTZ).balanceOf(address(user1));
        state = withdrawManagerLegacy.getWithdrawRequestState(withdrawRequestId);

        assertTrue(user1BalanceAfter - user1BalanceBefore == _withdrawRequest.amount);
        assertTrue(_withdrawRequest.claimed == true);
        assertTrue(state == DataTypes.WithdrawRequestStateLegacy.CLAIMED);
    }

    function _initialDeposit() internal {
        // deposit 1.5
        vm.startPrank(user1);
        IERC20(XTZ).approve(address(superloop), 1 * XTZ_SCALE);
        superloop.deposit(1 * XTZ_SCALE, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(XTZ).approve(address(superloop), (3 * XTZ_SCALE) / 10);
        superloop.deposit((3 * XTZ_SCALE) / 10, user2);
        vm.stopPrank();

        vm.startPrank(user3);
        IERC20(XTZ).approve(address(superloop), (2 * XTZ_SCALE) / 10);
        superloop.deposit((2 * XTZ_SCALE) / 10, user3);
        vm.stopPrank();
    }

    function _initialRebalance() internal {
        uint256 supplyAmount = 7 * STXTZ_SCALE;
        uint256 borrowAmount = (63 * XTZ_SCALE) / 10;
        uint256 swapAmount = borrowAmount + 1 * XTZ_SCALE;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 5) / 10000; // 5 bps premium

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);

        // 1. Deposit amount a in stxtz via aave supply module
        moduleExecutionData[0] = _supplyCall(ST_XTZ, supplyAmount);

        // 2. Borrow amount b in xtz via aave borrow module
        moduleExecutionData[1] = _borrowCall(XTZ, borrowAmount);

        // 3. Swap amount b + 1 in xtz for stxtz via the universal dex module
        moduleExecutionData[2] =
            _swapCallExactOut(XTZ, ST_XTZ, swapAmount, supplyAmountWithPremium, ROUTER, XTZ_STXTZ_POOL_FEE);

        // 1. pass data in flashloan
        // Create module execution data
        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] = _flashloanCall(ST_XTZ, supplyAmount, abi.encode(moduleExecutionData));

        vm.prank(admin);
        superloop.operate(finalExecutionData);
    }
}
