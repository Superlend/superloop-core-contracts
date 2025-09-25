// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {console} from "forge-std/console.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {AaveV3PreliquidationFallbackHandler} from
    "../../../src/modules/fallback/AaveV3PreliquidationFallbackHandler.sol";
import {console} from "forge-std/console.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract AavePreliquidationTest is IntegrationBase {
    function setUp() public override {
        super.setUp();

        DataTypes.AaveV3EmodeParams memory params = DataTypes.AaveV3EmodeParams({emodeCategory: 3});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(emodeModule),
            data: abi.encodeWithSelector(emodeModule.execute.selector, params)
        });

        vm.startPrank(admin);
        superloop.operate(moduleExecutionData);

        _deployPreliquidationFallbackHandler(address(superloop));
        bytes32 key1 = keccak256(
            abi.encodePacked(
                abi.encodeWithSelector(AaveV3PreliquidationFallbackHandler.preliquidate.selector),
                id,
                DataTypes.CallType.DELEGATECALL
            )
        );
        bytes32 key2 = keccak256(
            abi.encodePacked(
                abi.encodeWithSelector(AaveV3PreliquidationFallbackHandler.preliquidationParams.selector),
                id,
                DataTypes.CallType.DELEGATECALL
            )
        );

        superloop.setFallbackHandler(key1, address(preliquidationFallbackHandler));
        superloop.setFallbackHandler(key2, address(preliquidationFallbackHandler));
        vm.stopPrank();
    }

    function test_aavePreliquidationParams() public view {
        DataTypes.AaveV3PreliquidationParams memory params = AaveV3PreliquidationFallbackHandler(address(superloop))
            .preliquidationParams(id, DataTypes.CallType.DELEGATECALL);

        assertEq(params.lendReserve, ST_XTZ);
        assertEq(params.borrowReserve, XTZ);
        assertEq(params.Lltv, LLTV);
        assertEq(params.preLltv, PRE_LLTV);
        assertEq(params.preCF1, PRE_CF1);
        assertEq(params.preCF2, PRE_CF2);
        assertEq(params.preIF1, PRE_IF1);
        assertEq(params.preIF2, PRE_IF2);
    }

    function test_aavePreliquidation() public {
        _createPartialDepositWithResolution(true);

        (,, uint256 currentVariableDebt,,,,,,) =
            IPoolDataProvider(AAVE_V3_POOL_DATA_PROVIDER).getUserReserveData(XTZ, address(superloop));
        (uint256 currentATokenBalance,,,,,,,,) =
            IPoolDataProvider(AAVE_V3_POOL_DATA_PROVIDER).getUserReserveData(ST_XTZ, address(superloop));

        address liquidator = makeAddr("liquidator");
        deal(XTZ, liquidator, 1000 * XTZ_SCALE);

        uint256 userBalanceXTZBefore = IERC20(XTZ).balanceOf(liquidator);
        uint256 userBalanceSTXTZBefore = IERC20(ST_XTZ).balanceOf(liquidator);

        vm.startPrank(liquidator);
        IERC20(XTZ).approve(address(superloop), 1000 * XTZ_SCALE);

        AaveV3PreliquidationFallbackHandler(address(superloop)).preliquidate(
            id,
            DataTypes.CallType.DELEGATECALL,
            DataTypes.AaveV3ExecutePreliquidationParams({user: address(superloop), debtToCover: currentVariableDebt})
        );
        vm.stopPrank();

        (,, uint256 currentVariableDebtAfter,,,,,,) =
            IPoolDataProvider(AAVE_V3_POOL_DATA_PROVIDER).getUserReserveData(XTZ, address(superloop));
        (uint256 currentATokenBalanceAfter,,,,,,,,) =
            IPoolDataProvider(AAVE_V3_POOL_DATA_PROVIDER).getUserReserveData(ST_XTZ, address(superloop));

        uint256 userBalanceXTZAfter = IERC20(XTZ).balanceOf(liquidator);
        uint256 userBalanceSTXTZAfter = IERC20(ST_XTZ).balanceOf(liquidator);
        uint256 debtRepaid = currentVariableDebt - currentVariableDebtAfter;
        uint256 collateralWithdrawn = currentATokenBalance - currentATokenBalanceAfter;

        uint256 userBalanceXTZDiff = userBalanceXTZBefore - userBalanceXTZAfter;
        uint256 userBalanceSTXTZDiff = userBalanceSTXTZAfter - userBalanceSTXTZBefore;

        assertApproxEqRel(debtRepaid, userBalanceXTZDiff, 1e18);
        assertApproxEqRel(collateralWithdrawn, userBalanceSTXTZDiff, 1e18);

        IAaveOracle oracle = IAaveOracle(IPoolAddressesProvider(AAVE_V3_POOL_ADDRESSES_PROVIDER).getPriceOracle());
        uint256 stXtzPrice = oracle.getAssetPrice(ST_XTZ);
        uint256 xtzPrice = oracle.getAssetPrice(XTZ);

        uint256 debtRepaidUsd = (userBalanceXTZDiff * xtzPrice) / (10 ** 18);
        uint256 collateralWithdrawnUsd = (userBalanceSTXTZDiff * stXtzPrice) / (10 ** 6);

        uint256 incentiveWAD = (collateralWithdrawnUsd * WAD) / debtRepaidUsd;
        assertGe(incentiveWAD, PRE_IF1);
        assertLe(incentiveWAD, PRE_IF2);
    }
}
