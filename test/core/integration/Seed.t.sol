// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DepositManager} from "../../../src/core/DepositManager/DepositManager.sol";
import {console} from "forge-std/Test.sol";
import {Errors} from "../../../src/common/Errors.sol";

contract SeedTest is IntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function test_seed() public {
        uint256 vaultScale = 10 ** environment.vaultAssetDecimals;
        uint256 seedAmount = 10 * vaultScale;
        deal(environment.vaultAsset, admin, seedAmount);

        vm.startPrank(admin);
        IERC20(environment.vaultAsset).approve(address(superloop), seedAmount);
        superloop.seed(seedAmount);
        vm.stopPrank();

        uint256 totalSupply = superloop.totalSupply();

        assertApproxEqAbs(totalSupply, 10 * (vaultScale) * 100, 100);
        assertEq(superloop.totalAssets(), seedAmount);
        assertEq(superloop.balanceOf(admin), totalSupply);
    }

    function test_seed_failing_cases() public {
        uint256 vaultScale = 10 ** environment.vaultAssetDecimals;
        uint256 seedAmount = 10 * vaultScale;
        deal(environment.vaultAsset, user1, seedAmount);
        deal(environment.vaultAsset, admin, seedAmount);

        // should rever if not called by admin
        vm.startPrank(user1);
        IERC20(environment.vaultAsset).approve(address(superloop), seedAmount);
        vm.expectRevert(bytes(Errors.CALLER_NOT_VAULT_ADMIN));
        superloop.seed(seedAmount);
        vm.stopPrank();

        // should not seed with 0 assets
        vm.startPrank(admin);
        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        superloop.seed(0);
        vm.stopPrank();

        // should seed
        vm.startPrank(admin);
        IERC20(environment.vaultAsset).approve(address(superloop), seedAmount);
        superloop.seed(seedAmount);
        vm.stopPrank();

        // should revert if already seeded
        vm.startPrank(admin);
        vm.expectRevert(bytes(Errors.VAULT_ALREADY_SEEDED));
        superloop.seed(seedAmount);
        vm.stopPrank();
    }
}
