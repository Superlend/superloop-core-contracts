// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DepositManager} from "../../../src/core/DepositManager/DepositManager.sol";
import {console} from "forge-std/Test.sol";
import {Errors} from "../../../src/common/Errors.sol";

contract InstantWithdrawTest is IntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function test_instantWithdraw() public {
        _seed();

        uint256 userSharesBalanceBefore = superloop.balanceOf(admin);
        uint256 userTokenBalanceBefore = IERC20(XTZ).balanceOf(admin);
        uint256 treasurySharesBalanceBefore = superloop.balanceOf(treasury);

        vm.startPrank(admin);
        uint256 instantWithdrawAmount = 10 * XTZ_SCALE;
        superloop.withdraw(instantWithdrawAmount, admin, admin);

        uint256 userSharesBalanceAfter = superloop.balanceOf(admin);
        uint256 userTokenBalanceAfter = IERC20(XTZ).balanceOf(admin);
        uint256 treasurySharesBalanceAfter = superloop.balanceOf(treasury);

        uint256 instantWithdrawFee = (instantWithdrawAmount * INSTANT_WITHDRAW_FEE) / 10_000;
        assertEq(userSharesBalanceBefore - userSharesBalanceAfter, instantWithdrawAmount * 100);
        assertEq(userTokenBalanceAfter - userTokenBalanceBefore, instantWithdrawAmount - instantWithdrawFee);
        assertEq(treasurySharesBalanceAfter - treasurySharesBalanceBefore, instantWithdrawFee * 100);
    }

    function test_instantRedeem() public {
        _seed();

        uint256 userSharesBalanceBefore = superloop.balanceOf(admin);
        uint256 userTokenBalanceBefore = IERC20(XTZ).balanceOf(admin);
        uint256 treasurySharesBalanceBefore = superloop.balanceOf(treasury);

        vm.startPrank(admin);
        uint256 instantRedeemAmount = 10 * ONE_SHARE;
        superloop.redeem(instantRedeemAmount, admin, admin);

        uint256 userSharesBalanceAfter = superloop.balanceOf(admin);
        uint256 userTokenBalanceAfter = IERC20(XTZ).balanceOf(admin);
        uint256 treasurySharesBalanceAfter = superloop.balanceOf(treasury);

        uint256 instantRedeemFee = (instantRedeemAmount * INSTANT_WITHDRAW_FEE) / 10_000;
        assertEq(userSharesBalanceBefore - userSharesBalanceAfter, instantRedeemAmount);
        assertEq(userTokenBalanceAfter - userTokenBalanceBefore, (instantRedeemAmount - instantRedeemFee) / 100);
        assertEq(treasurySharesBalanceAfter - treasurySharesBalanceBefore, instantRedeemFee);
    }

    function _seed() internal {
        uint256 seedAmount = 100 * XTZ_SCALE;
        deal(XTZ, admin, seedAmount);

        vm.startPrank(admin);
        IERC20(XTZ).approve(address(superloop), seedAmount);
        superloop.seed(seedAmount);
        vm.stopPrank();

        uint256 totalSupply = superloop.totalSupply();

        assertApproxEqAbs(totalSupply, seedAmount * 100, 100);
        assertEq(superloop.totalAssets(), seedAmount);
        assertEq(superloop.balanceOf(admin), totalSupply);
    }
}
