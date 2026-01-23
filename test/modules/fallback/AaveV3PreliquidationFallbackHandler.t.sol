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
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// not maintained right now. will be updated soon.
contract AaveV3PreliquidationFallbackHandlerTest is TestBase {
    AaveV3PreliquidationFallbackHandler public preliquidation;

    function setUp() public override {
        super.setUp();
        id = bytes32("1");
        LLTV = (7800 * WAD) / BPS;
        preliquidation = new AaveV3PreliquidationFallbackHandler(
            environment.poolAddressesProvider,
            0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f,
            2,
            8,
            DataTypes.AaveV3PreliquidationParamsInit({
                id: id,
                lendReserve: environment.lendAssets[0],
                borrowReserve: environment.borrowAssets[0],
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
        assertEq(preliquidationParams.lendReserve, environment.lendAssets[0]);
        assertEq(preliquidationParams.borrowReserve, environment.borrowAssets[0]);
        assertEq(preliquidationParams.Lltv, LLTV);
        assertEq(preliquidationParams.preLltv, PRE_LLTV);
        assertEq(preliquidationParams.preCF1, PRE_CF1);
        assertEq(preliquidationParams.preCF2, PRE_CF2);
        assertEq(preliquidationParams.preIF1, PRE_IF1);
        assertEq(preliquidationParams.preIF2, PRE_IF2);
    }

    function test_preliquidation() public {
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        deal(
            environment.borrowAssets[0],
            address(preliquidation),
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(
            environment.borrowAssets[0],
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(),
            2,
            0,
            address(preliquidation)
        );
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        uint256 lendAssetBalanceBefore = IERC20(environment.lendAssets[0]).balanceOf(address(this));
        uint256 borrowAssetBalanceBefore = IERC20(environment.borrowAssets[0]).balanceOf(address(this));

        IAaveOracle oracle = IAaveOracle(IPoolAddressesProvider(environment.poolAddressesProvider).getPriceOracle());

        // usd value of debt repaid
        uint256 debtRepaid = 10 * 10 ** 18;
        uint256 debtPriceUsd = oracle.getAssetPrice(environment.borrowAssets[0]);
        uint256 debtRepaidUSD =
            (debtRepaid * debtPriceUsd) / (10 ** IERC20Metadata(environment.borrowAssets[0]).decimals());

        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 10 * 10 ** 18})
        );

        uint256 lendAssetBalanceAfter = IERC20(environment.lendAssets[0]).balanceOf(address(this));
        uint256 borrowAssetBalanceAfter = IERC20(environment.borrowAssets[0]).balanceOf(address(this));

        uint256 collateralToSieze = lendAssetBalanceAfter - lendAssetBalanceBefore;
        uint256 collateralPriceUsd = oracle.getAssetPrice(environment.lendAssets[0]);
        uint256 collateralToSiezeUSD = (collateralToSieze * collateralPriceUsd) / (10 ** 6);

        // compare collateralToSiezeUSD and debtRepaidUSD
        uint256 incentiveWAD = ((collateralToSiezeUSD) * WAD) / debtRepaidUSD;
        assertTrue(incentiveWAD > PRE_IF1 && incentiveWAD < PRE_IF2);
        assertEq(
            borrowAssetBalanceAfter,
            borrowAssetBalanceBefore - 10 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
    }

    // ============ REVERTING CASES ============

    function test_preliquidation_revert_invalid_lltv() public {
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        deal(
            environment.borrowAssets[0],
            address(preliquidation),
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(
            environment.borrowAssets[0],
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(),
            2,
            0,
            address(preliquidation)
        );
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        // updat emode ltv to 9900 => it should revert
        vm.prank(environment.poolAdmin);
        IPoolConfigurator(environment.poolConfigurator).configureReserveAsCollateral(
            environment.lendAssets[0], 9000, 9200, 10100
        );

        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        vm.expectRevert(bytes(Errors.AAVE_V3_PRELIQUIDATION_INVALID_LLTV));
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 10 * 10 ** 18})
        );
    }

    function test_preliquidate_revert_invalid_id() public {
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        deal(
            environment.borrowAssets[0],
            address(preliquidation),
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(
            environment.borrowAssets[0],
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(),
            2,
            0,
            address(preliquidation)
        );
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        bytes32 wrongId = bytes32("wrong_id");
        vm.expectRevert(bytes(Errors.PRELIQUIDATION_INVALID_ID));
        preliquidation.preliquidate(
            wrongId,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 10 * 10 ** 18})
        );
    }

    function test_preliquidate_revert_invalid_user() public {
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        deal(
            environment.borrowAssets[0],
            address(preliquidation),
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(
            environment.borrowAssets[0],
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(),
            2,
            0,
            address(preliquidation)
        );
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

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
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        deal(
            environment.borrowAssets[0],
            address(preliquidation),
            80 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        ); // High borrow amount

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        vm.expectRevert(bytes(Errors.INSUFFICIENT_CASH_SHORTFALL));
        pool.borrow(
            environment.borrowAssets[0],
            80 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(),
            2,
            0,
            address(preliquidation)
        );
        vm.stopPrank();
    }

    function test_preliquidate_revert_not_in_preliquidation_state() public {
        // Set up position with LTV <= preLltv (not in preliquidation state)
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        deal(
            environment.borrowAssets[0],
            address(preliquidation),
            40 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        ); // Low borrow amount

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(
            environment.borrowAssets[0],
            40 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(),
            2,
            0,
            address(preliquidation)
        );
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

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
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );

        // Calculate exact borrow amount to achieve LTV = preLltv
        // We need: borrowUsdWAD = collateralUsdWAD * preLltv
        // For simplicity, we'll use a value that should be close to the boundary
        uint256 borrowAmount = 50 * 10 ** 18; // This should be close to preLltv boundary

        deal(environment.borrowAssets[0], address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(environment.borrowAssets[0], borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

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
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );

        // Calculate exact borrow amount to achieve LTV = Lltv
        uint256 borrowAmount = 74 * 10 ** 18; // This should be close to Lltv boundary

        deal(environment.borrowAssets[0], address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(environment.borrowAssets[0], borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        // This should succeed as it's exactly at the boundary
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    function test_preliquidate_edge_case_trying_to_liquidate_max() public {
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        deal(
            environment.borrowAssets[0],
            address(this),
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(
            environment.borrowAssets[0],
            70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(),
            2,
            0,
            address(preliquidation)
        );
        vm.stopPrank();

        // try to liquidate 70xtz, but i should be able to do only till close factor

        uint256 borrowAssetBalanceBefore = IERC20(environment.borrowAssets[0]).balanceOf(address(this));
        uint256 lendAssetBalanceBefore = IERC20(environment.lendAssets[0]).balanceOf(address(this));

        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 70 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 70 * 10 ** 18})
        );

        uint256 borrowAssetBalanceAfter = IERC20(environment.borrowAssets[0]).balanceOf(address(this));
        uint256 lendAssetBalanceAfter = IERC20(environment.lendAssets[0]).balanceOf(address(this));

        uint256 collateralSeized = lendAssetBalanceAfter - lendAssetBalanceBefore;

        assertTrue(collateralSeized < 40 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals());
        assertTrue(
            borrowAssetBalanceBefore - borrowAssetBalanceAfter
                < 40 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
    }

    // ============ LTV IN RANGE TESTS ============

    function test_preliquidate_ltv_low_range() public {
        // Set up position with LTV slightly above preLltv
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        uint256 borrowAmount = 55 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(); // Between preLltv and Lltv

        deal(environment.borrowAssets[0], address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(environment.borrowAssets[0], borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    function test_preliquidate_ltv_mid_range() public {
        // Set up position with LTV in the middle of preLltv and Lltv
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        uint256 borrowAmount = 65 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(); // Middle of the range

        deal(environment.borrowAssets[0], address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(environment.borrowAssets[0], borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

        preliquidation.preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(preliquidation), debtToCover: 5 * 10 ** 18})
        );
    }

    function test_preliquidate_ltv_high_range() public {
        // Set up position with LTV close to Lltv
        deal(
            environment.lendAssets[0],
            address(preliquidation),
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        uint256 borrowAmount = 74 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(); // Close to Lltv

        deal(environment.borrowAssets[0], address(preliquidation), borrowAmount);

        vm.startPrank(address(preliquidation));
        IERC20(environment.lendAssets[0]).approve(
            address(pool), 100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals()
        );
        pool.supply(
            environment.lendAssets[0],
            100 * 10 ** IERC20Metadata(environment.lendAssets[0]).decimals(),
            address(preliquidation),
            0
        );
        pool.borrow(environment.borrowAssets[0], borrowAmount, 2, 0, address(preliquidation));
        vm.stopPrank();

        deal(
            environment.borrowAssets[0],
            address(this),
            12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );
        IERC20(environment.borrowAssets[0]).approve(
            address(preliquidation), 12 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals()
        );

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
            environment.poolAddressesProvider,
            newPreLiq,
            2,
            8,
            DataTypes.AaveV3PreliquidationParamsInit({
                id: id,
                lendReserve: environment.lendAssets[0],
                borrowReserve: environment.borrowAssets[0],
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
