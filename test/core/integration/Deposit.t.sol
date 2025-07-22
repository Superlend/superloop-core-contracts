// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DepositTest is IntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    // DEPOSIT FLOW
    // deposit by few different users a total of 1 xtz
    function test_deposit() public {
        vm.startPrank(user1);
        IERC20(XTZ).approve(address(superloop), (5 * XTZ_SCALE) / 10);
        superloop.deposit((5 * XTZ_SCALE) / 10, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(XTZ).approve(address(superloop), (3 * XTZ_SCALE) / 10);
        superloop.deposit((3 * XTZ_SCALE) / 10, user2);
        vm.stopPrank();

        vm.startPrank(user3);
        IERC20(XTZ).approve(address(superloop), (2 * XTZ_SCALE) / 10);
        superloop.deposit((2 * XTZ_SCALE) / 10, user3);
        vm.stopPrank();

        assertEq(superloop.totalAssets(), 1 * XTZ_SCALE);
        assertEq(superloop.balanceOf(user1), 5 * XTZ_SCALE * 10); // this extra 10 needs to be added because decimal offset is 2
        assertEq(superloop.balanceOf(user2), 3 * XTZ_SCALE * 10);
        assertEq(superloop.balanceOf(user3), 2 * XTZ_SCALE * 10);
    }
}
