// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {console} from "forge-std/console.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {
    AaveV3PreliquidationFallbackHandler
} from "../../../src/modules/fallback/AaveV3PreliquidationFallbackHandler.sol";
import {console} from "forge-std/console.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract AavePreliquidationTest is IntegrationBase {
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

        assertEq(params.lendReserve, environment.lendAssets[0]);
        assertEq(params.borrowReserve, environment.borrowAssets[0]);
        assertEq(params.Lltv, LLTV);
        assertEq(params.preLltv, PRE_LLTV);
        assertEq(params.preCF1, PRE_CF1);
        assertEq(params.preCF2, PRE_CF2);
        assertEq(params.preIF1, PRE_IF1);
        assertEq(params.preIF2, PRE_IF2);
    }

    function test_aavePreliquidation() public {
        _createPartialDepositWithResolution(true);

        (,, uint256 currentVariableDebt,,,,,,) = IPoolDataProvider(environment.poolAddressesProvider)
            .getUserReserveData(environment.borrowAssets[0], address(superloop));
        (uint256 currentATokenBalance,,,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.lendAssets[0], address(superloop));

        address liquidator = makeAddr("liquidator");
        deal(environment.borrowAssets[0], liquidator, 1000 * environment.vaultAssetDecimals);

        uint256 userBalanceXTZBefore = IERC20(environment.borrowAssets[0]).balanceOf(liquidator);
        uint256 userBalanceSTXTZBefore = IERC20(environment.lendAssets[0]).balanceOf(liquidator);

        vm.startPrank(liquidator);
        IERC20(environment.borrowAssets[0]).approve(address(superloop), 1000 * environment.vaultAssetDecimals);

        AaveV3PreliquidationFallbackHandler(address(superloop))
            .preliquidate(
                id,
                DataTypes.CallType.DELEGATECALL,
                DataTypes.AaveV3ExecutePreliquidationParams({
                user: address(superloop), debtToCover: currentVariableDebt
            })
            );
        vm.stopPrank();

        (,, uint256 currentVariableDebtAfter,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.borrowAssets[0], address(superloop));
        (uint256 currentATokenBalanceAfter,,,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.lendAssets[0], address(superloop));

        uint256 userBalanceXTZAfter = IERC20(environment.borrowAssets[0]).balanceOf(liquidator);
        uint256 userBalanceSTXTZAfter = IERC20(environment.lendAssets[0]).balanceOf(liquidator);
        uint256 debtRepaid = currentVariableDebt - currentVariableDebtAfter;
        uint256 collateralWithdrawn = currentATokenBalance - currentATokenBalanceAfter;

        uint256 userBalanceXTZDiff = userBalanceXTZBefore - userBalanceXTZAfter;
        uint256 userBalanceSTXTZDiff = userBalanceSTXTZAfter - userBalanceSTXTZBefore;

        assertApproxEqRel(debtRepaid, userBalanceXTZDiff, 1e18);
        assertApproxEqRel(collateralWithdrawn, userBalanceSTXTZDiff, 1e18);

        IAaveOracle oracle = IAaveOracle(IPoolAddressesProvider(environment.poolAddressesProvider).getPriceOracle());
        uint256 stXtzPrice = oracle.getAssetPrice(environment.lendAssets[0]);
        uint256 xtzPrice = oracle.getAssetPrice(environment.borrowAssets[0]);

        uint256 debtRepaidUsd = (userBalanceXTZDiff * xtzPrice) / (10 ** 18);
        uint256 collateralWithdrawnUsd = (userBalanceSTXTZDiff * stXtzPrice) / (10 ** 6);

        uint256 incentiveWAD = (collateralWithdrawnUsd * WAD) / debtRepaidUsd;
        assertGe(incentiveWAD, PRE_IF1);
        assertLe(incentiveWAD, PRE_IF2);
    }
}
