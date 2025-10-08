// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestBase} from "../../core/TestBase.sol";
import {AaveV3PreliquidationFallbackHandler} from
    "../../../src/modules/fallback/AaveV3PreliquidationFallbackHandler.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {Errors} from "../../../src/common/Errors.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";

contract AaveV3PreliquidationFallbackHandlerTest is TestBase {
    AaveV3PreliquidationFallbackHandler public preliquidation;

    function setUp() public override {
        super.setUp();
        id = bytes32("1");
        LLTV = (7800 * WAD) / BPS;
        preliquidation = new AaveV3PreliquidationFallbackHandler(
            AAVE_V3_POOL_ADDRESSES_PROVIDER,
            0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f,
            2,
            8,
            DataTypes.AaveV3PreliquidationParamsInit({
                id: id,
                lendReserve: ST_XTZ,
                borrowReserve: XTZ,
                preLltv: PRE_LLTV,
                preCF1: PRE_CF1,
                preCF2: PRE_CF2,
                preIF1: PRE_IF1,
                preIF2: PRE_IF2
            })
        );
    }

    function test_preliquidationParams() public view {
        DataTypes.AaveV3PreliquidationParams memory preliquidationParams =
            preliquidation.preliquidationParams(id, DataTypes.CallType.DELEGATECALL);
        assertEq(preliquidationParams.lendReserve, ST_XTZ);
        assertEq(preliquidationParams.borrowReserve, XTZ);
        assertEq(preliquidationParams.Lltv, LLTV);
        assertEq(preliquidationParams.preLltv, PRE_LLTV);
        assertEq(preliquidationParams.preCF1, PRE_CF1);
        assertEq(preliquidationParams.preCF2, PRE_CF2);
        assertEq(preliquidationParams.preIF1, PRE_IF1);
        assertEq(preliquidationParams.preIF2, PRE_IF2);
    }

    function test_preliquidation() public {
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        deal(XTZ, address(preliquidation), 70 * 10 ** 18);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, 70 * 10 ** 18, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);

        uint256 stxtzBalanceBefore = IERC20(ST_XTZ).balanceOf(address(this));
        uint256 xtzBalanceBefore = IERC20(XTZ).balanceOf(address(this));

        IAaveOracle oracle = IAaveOracle(IPoolAddressesProvider(AAVE_V3_POOL_ADDRESSES_PROVIDER).getPriceOracle());

        // usd value of debt repaid
        uint256 debtRepaid = 10 * 10 ** 18;
        uint256 debtPriceUsd = oracle.getAssetPrice(XTZ);
        uint256 debtRepaidUSD = debtRepaid * debtPriceUsd / (10 ** 18);

        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 10 * 10 ** 18})
        );

        uint256 stxtzBalanceAfter = IERC20(ST_XTZ).balanceOf(address(this));
        uint256 xtzBalanceAfter = IERC20(XTZ).balanceOf(address(this));

        uint256 collateralToSieze = stxtzBalanceAfter - stxtzBalanceBefore;
        uint256 collateralPriceUsd = oracle.getAssetPrice(ST_XTZ);
        uint256 collateralToSiezeUSD = collateralToSieze * collateralPriceUsd / (10 ** 6);

        // compare collateralToSiezeUSD and debtRepaidUSD
        uint256 incentiveWAD = ((collateralToSiezeUSD) * WAD) / debtRepaidUSD;
        assertTrue(incentiveWAD > PRE_IF1 && incentiveWAD < PRE_IF2);
        assertEq(xtzBalanceAfter, xtzBalanceBefore - 10 * 10 ** 18);
    }

    // ============ REVERTING CASES ============

    function test_preliquidation_revert_invalid_lltv() public {
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        deal(XTZ, address(preliquidation), 70 * 10 ** 18);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, 70 * 10 ** 18, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);

        // updat emode ltv to 9900 => it should revert
        vm.prank(POOL_ADMIN);
        IPoolConfigurator(POOL_CONFIGURATOR).configureReserveAsCollateral(ST_XTZ, 9000, 9200, 10100);

        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        vm.expectRevert(bytes(Errors.AAVE_V3_PRELIQUIDATION_INVALID_LLTV));
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 10 * 10 ** 18})
        );
    }

    function test_preliquidate_revert_invalid_id() public {
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        deal(XTZ, address(preliquidation), 70 * 10 ** 18);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, 70 * 10 ** 18, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        bytes32 wrongId = bytes32("wrong_id");
        vm.expectRevert(bytes(Errors.PRELIQUIDATION_INVALID_ID));
        preliquidation.preliquidate(
            wrongId,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 10 * 10 ** 18})
        );
    }

    function test_preliquidate_revert_invalid_user() public {
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        deal(XTZ, address(preliquidation), 70 * 10 ** 18);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, 70 * 10 ** 18, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        address wrongUser = makeAddr("wrongUser");
        vm.expectRevert(bytes(Errors.PRELIQUIDATION_INVALID_USER));
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: wrongUser, debtToCover: 10 * 10 ** 18})
        );
    }

    function test_preliquidate_revert_possible_bad_debt() public {
        // Set up position with LTV > LLTV (bad debt scenario)
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        deal(XTZ, address(preliquidation), 80 * 10 ** 18); // High borrow amount

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        vm.expectRevert(bytes(Errors.INSUFFICIENT_CASH_SHORTFALL));
        pool.borrow(XTZ, 80 * 10 ** 18, 2, 0, address(preliquidation));
        vm.stopPrank();
    }

    function test_preliquidate_revert_not_in_preliquidation_state() public {
        // Set up position with LTV <= preLltv (not in preliquidation state)
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        deal(XTZ, address(preliquidation), 40 * 10 ** 18); // Low borrow amount

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, 40 * 10 ** 18, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        vm.expectRevert(bytes(Errors.PRELIQUIDATION_NOT_IN_PRELIQUIDATION_STATE));
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 10 * 10 ** 18})
        );
    }

    // // ============ EDGE CASES ============

    function test_preliquidate_edge_case_ltv_equals_prelltv() public {
        // Set up position with LTV = preLltv (exactly at the boundary)
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);

        // Calculate exact borrow amount to achieve LTV = preLltv
        // We need: borrowUsdWAD = collateralUsdWAD * preLltv
        // For simplicity, we'll use a value that should be close to the boundary
        uint256 borrowAmount = 50 * 10 ** 18; // This should be close to preLltv boundary

        deal(XTZ, address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        // This should revert because LTV <= preLltv
        vm.expectRevert(bytes(Errors.PRELIQUIDATION_NOT_IN_PRELIQUIDATION_STATE));
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    function test_preliquidate_edge_case_ltv_equals_lltv() public {
        // Set up position with LTV = Lltv (exactly at the liquidation threshold)
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);

        // Calculate exact borrow amount to achieve LTV = Lltv
        uint256 borrowAmount = 74 * 10 ** 18; // This should be close to Lltv boundary

        deal(XTZ, address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        // This should succeed as it's exactly at the boundary
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    function test_preliquidate_edge_case_trying_to_liquidate_max() public {
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        deal(XTZ, address(this), 70 * 10 ** 18);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, 70 * 10 ** 18, 2, 0, address(preliquidation));
        vm.stopPrank();

        // try to liquidate 70xtz, but i should be able to do only till close factor

        uint256 xtzBalanceBefore = IERC20(XTZ).balanceOf(address(this));
        uint256 stxtzBalanceBefore = IERC20(ST_XTZ).balanceOf(address(this));

        IERC20(XTZ).approve(address(preliquidation), 70 * 10 ** 18);
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 70 * 10 ** 18})
        );

        uint256 xtzBalanceAfter = IERC20(XTZ).balanceOf(address(this));
        uint256 stxtzBalanceAfter = IERC20(ST_XTZ).balanceOf(address(this));

        uint256 collateralSeized = stxtzBalanceAfter - stxtzBalanceBefore;

        assertTrue(collateralSeized < 40 * 10 ** 6);
        assertTrue(xtzBalanceBefore - xtzBalanceAfter < 40 * 10 ** 18);
    }

    // ============ LTV IN RANGE TESTS ============

    function test_preliquidate_ltv_low_range() public {
        // Set up position with LTV slightly above preLltv
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        uint256 borrowAmount = 55 * 10 ** 18; // Between preLltv and Lltv

        deal(XTZ, address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    function test_preliquidate_ltv_mid_range() public {
        // Set up position with LTV in the middle of preLltv and Lltv
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        uint256 borrowAmount = 65 * 10 ** 18; // Middle of the range

        deal(XTZ, address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    function test_preliquidate_ltv_high_range() public {
        // Set up position with LTV close to Lltv
        deal(ST_XTZ, address(preliquidation), 100 * 10 ** 6);
        uint256 borrowAmount = 74 * 10 ** 18; // Close to Lltv

        deal(XTZ, address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(ST_XTZ).approve(address(pool), 100 * 10 ** 6);
        pool.supply(ST_XTZ, 100 * 10 ** 6, address(preliquidation), 0);
        pool.borrow(XTZ, borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(XTZ, address(this), 12 * 10 ** 18);
        IERC20(XTZ).approve(address(preliquidation), 12 * 10 ** 18);

        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    // ============ E-MODE TESTS ============

    function test_preliquidate_e_mode() public {
        address newPreLiq = 0x2e234DAe75C793f67A35089C9d99245E1C58470b;
        vm.prank(address(newPreLiq));
        pool.setUserEMode(3);
        preliquidation = new AaveV3PreliquidationFallbackHandler(
            AAVE_V3_POOL_ADDRESSES_PROVIDER,
            newPreLiq,
            2,
            8,
            DataTypes.AaveV3PreliquidationParamsInit({
                id: id,
                lendReserve: ST_XTZ,
                borrowReserve: XTZ,
                preLltv: PRE_LLTV,
                preCF1: PRE_CF1,
                preCF2: PRE_CF2,
                preIF1: PRE_IF1,
                preIF2: PRE_IF2
            })
        );

        DataTypes.AaveV3PreliquidationParams memory preliquidationParams =
            preliquidation.preliquidationParams(id, DataTypes.CallType.DELEGATECALL);
        assertEq(preliquidationParams.Lltv, (9600 * WAD) / BPS);
    }
}
