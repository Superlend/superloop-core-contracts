// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IRouter} from "../../../src/mock/MockIRouter.sol";
import {IPriceOracleGetter} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";

contract RebalanceTest is IntegrationBase {
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

    // REBALANCE FLOW
    // do the rebalance such that we achieve a leverage of 7x
    function test_initialRebalance() public {
        // How to leverage
        // 1. Flashloan 7xtz equivalent of stxtz (lets call it amount a) via aave flashloan module
        // 2. Deposit amount a in stxtz via aave supply module
        // 3. Borrow enough xtz to cover the flashloan amount + premium (keep in mind we have 1 xtz in the vault from the initial deposit, that will contribute to the amount to be borrowed) via aave borrow module
        // 4. Swap the borrowed xtz for stxtz via the universal dex module
        // we end with a stXTZ in exposure and 7.x xtz as borrow

        _initialDeposit();
        _initialRebalance();

        (uint256 currentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, address(superloop));
        (,, uint256 currentVariableDebt,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        uint256 currentXtzBalance = IERC20(XTZ).balanceOf(address(superloop));
        uint256 totalAssets = superloop.totalAssets();

        assert(totalAssets >= (15 * XTZ_SCALE) / 10);
        assert(currentATokenBalance > 0);
        assert(currentVariableDebt > 0);
        assert(currentXtzBalance > 0);
    }

    // UPDATE REBALANCE FLOW
    // deposit 1 more xtz
    // rebalance ie. achieve the leverage of 7x again which would have been disturbed by new deposits
    function test_adjustLeverageForNewDeposit() public {
        _initialDeposit();
        _initialRebalance();

        uint256 currentStxtzPrice = IPriceOracleGetter(AAVE_V3_PRICE_ORACLE).getAssetPrice(ST_XTZ);
        // move timestamp up by 30 days
        vm.warp(block.timestamp + 30 days);

        // mock oracle of stXTZ price to be 1.01 times the current price
        vm.mockCall(
            address(AAVE_V3_PRICE_ORACLE),
            abi.encodeWithSelector(IPriceOracleGetter.getAssetPrice.selector, ST_XTZ),
            abi.encode((currentStxtzPrice * 101) / 100)
        );

        // deposit 1
        vm.startPrank(user1);
        IERC20(XTZ).approve(address(superloop), 1 * XTZ_SCALE);
        superloop.deposit(1 * XTZ_SCALE, user1);
        vm.stopPrank();

        // now try to achieve a total exposure of 12 stXTZ
        uint256 newSupplyAmount = 5 * STXTZ_SCALE;
        uint256 newBorrowAmount = (45 * XTZ_SCALE) / 10;
        uint256 swapAmount = newBorrowAmount + 1 * XTZ_SCALE;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);

        // 1. Deposit amount a in stxtz via aave supply module
        DataTypes.AaveV3ActionParams memory supplyParams =
            DataTypes.AaveV3ActionParams({asset: ST_XTZ, amount: newSupplyAmount});
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(supplyModule),
            data: abi.encodeWithSelector(supplyModule.execute.selector, supplyParams)
        });

        // // 2. Borrow amount b in xtz via aave borrow module
        DataTypes.AaveV3ActionParams memory borrowParams =
            DataTypes.AaveV3ActionParams({asset: XTZ, amount: newBorrowAmount});
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(borrowModule),
            data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
        });

        // 3. Swap amount b + 1 in xtz for stxtz via the universal dex module
        uint256 supplyAmountWithPremium = newSupplyAmount + (newSupplyAmount * 5) / 10000; // 5 bps premium
        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: XTZ,
            data: abi.encodeWithSelector(IERC20.approve.selector, ROUTER, swapAmount)
        });
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: ROUTER,
            data: abi.encodeWithSelector(
                IRouter.exactOutputSingle.selector,
                IRouter.ExactOutputSingleParams({
                    tokenIn: XTZ,
                    tokenOut: ST_XTZ,
                    fee: XTZ_STXTZ_POOL_FEE,
                    recipient: address(superloop),
                    amountOut: supplyAmountWithPremium,
                    amountInMaximum: swapAmount,
                    sqrtPriceLimitX96: 0
                })
            )
        });
        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: XTZ,
            tokenOut: ST_XTZ,
            amountIn: swapAmount,
            maxAmountIn: swapAmount,
            minAmountOut: supplyAmountWithPremium,
            data: swapParamsData
        });

        moduleExecutionData[2] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });

        // 1. pass data in flashloan
        bytes memory dataForFlashloan = abi.encode(moduleExecutionData);
        DataTypes.AaveV3FlashloanParams memory flashloanParams = DataTypes.AaveV3FlashloanParams({
            asset: ST_XTZ,
            amount: newSupplyAmount,
            referralCode: 0,
            callbackExecutionData: dataForFlashloan
        });

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(flashloanModule),
            data: abi.encodeWithSelector(flashloanModule.execute.selector, flashloanParams)
        });

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        (uint256 currentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, address(superloop));
        (,, uint256 currentVariableDebt,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        uint256 currentXtzBalance = IERC20(XTZ).balanceOf(address(superloop));
        uint256 totalAssets = superloop.totalAssets();

        assert(totalAssets >= (25 * XTZ_SCALE) / 10);
        assert(currentATokenBalance > 0);
        assert(currentVariableDebt > 0);
        assert(currentXtzBalance > 0);
    }

    // REBALANCE TO DELEVERAGE
    // reduce leverage from 7x to 5x
    function test_adjustDeleverage() public {
        _initialDeposit();
        _initialRebalance();
        // move the leverage from 7x to 5x
        // update exposure of stxtz to 5 stxtz

        // Steps
        // 1. flash loan 2.5 xtz
        // 2. repay 2.5 xtz
        // 3. withdraw 2 stXtz
        // 4. swap 2 stxtz for all the xtz it can give ie. exact input

        uint256 repayAmount = (19 * XTZ_SCALE) / 10; // ideally this should be more than 2, set to 1.9 becuase iguana dex has incorrect price
        uint256 withdrawAmount = 2 * STXTZ_SCALE;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        DataTypes.AaveV3ActionParams memory repayParams =
            DataTypes.AaveV3ActionParams({asset: XTZ, amount: repayAmount});
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(repayModule),
            data: abi.encodeWithSelector(repayModule.execute.selector, repayParams)
        });

        DataTypes.AaveV3ActionParams memory withdrawParams =
            DataTypes.AaveV3ActionParams({asset: ST_XTZ, amount: withdrawAmount});
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(withdrawModule),
            data: abi.encodeWithSelector(withdrawModule.execute.selector, withdrawParams)
        });
        // ----

        uint256 repayAmountWithPremium = repayAmount + (repayAmount * 5) / 10000; // 5 bps premium

        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: ST_XTZ,
            data: abi.encodeWithSelector(IERC20.approve.selector, ROUTER, withdrawAmount)
        });
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: ROUTER,
            data: abi.encodeWithSelector(
                IRouter.exactInputSingle.selector,
                IRouter.ExactInputSingleParams({
                    tokenIn: ST_XTZ,
                    tokenOut: XTZ,
                    fee: XTZ_STXTZ_POOL_FEE,
                    recipient: address(superloop),
                    amountIn: withdrawAmount,
                    amountOutMinimum: repayAmountWithPremium,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: ST_XTZ,
            tokenOut: XTZ,
            amountIn: withdrawAmount,
            maxAmountIn: withdrawAmount,
            minAmountOut: repayAmountWithPremium,
            data: swapParamsData
        });

        moduleExecutionData[2] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });

        bytes memory dataForFlashloan = abi.encode(moduleExecutionData);
        DataTypes.AaveV3FlashloanParams memory flashloanParams = DataTypes.AaveV3FlashloanParams({
            asset: XTZ,
            amount: repayAmount,
            referralCode: 0,
            callbackExecutionData: dataForFlashloan
        });

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(flashloanModule),
            data: abi.encodeWithSelector(flashloanModule.execute.selector, flashloanParams)
        });

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        (uint256 currentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(ST_XTZ, address(superloop));
        (,, uint256 currentVariableDebt,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        uint256 currentXtzBalance = IERC20(XTZ).balanceOf(address(superloop));
        uint256 totalAssets = superloop.totalAssets();

        assert(totalAssets >= (15 * XTZ_SCALE) / 10);
        assert(currentATokenBalance > 0);
        assert(currentVariableDebt > 0);
        assert(currentXtzBalance > 0);
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
        uint256 borrowAmount = 6 * XTZ_SCALE;
        uint256 swapAmount = borrowAmount + 1 * XTZ_SCALE;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);

        // 1. Deposit amount a in stxtz via aave supply module
        DataTypes.AaveV3ActionParams memory supplyParams =
            DataTypes.AaveV3ActionParams({asset: ST_XTZ, amount: supplyAmount});
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(supplyModule),
            data: abi.encodeWithSelector(supplyModule.execute.selector, supplyParams)
        });

        // 2. Borrow amount b in xtz via aave borrow module
        DataTypes.AaveV3ActionParams memory borrowParams =
            DataTypes.AaveV3ActionParams({asset: XTZ, amount: borrowAmount});
        moduleExecutionData[1] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(borrowModule),
            data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
        });

        // 3. Swap amount b + 1 in xtz for stxtz via the universal dex module
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 5) / 10000; // 5 bps premium
        DataTypes.ExecuteSwapParamsData[] memory swapParamsData = new DataTypes.ExecuteSwapParamsData[](2);
        swapParamsData[0] = DataTypes.ExecuteSwapParamsData({
            target: XTZ,
            data: abi.encodeWithSelector(IERC20.approve.selector, ROUTER, swapAmount)
        });
        swapParamsData[1] = DataTypes.ExecuteSwapParamsData({
            target: ROUTER,
            data: abi.encodeWithSelector(
                IRouter.exactOutputSingle.selector,
                IRouter.ExactOutputSingleParams({
                    tokenIn: XTZ,
                    tokenOut: ST_XTZ,
                    fee: XTZ_STXTZ_POOL_FEE,
                    recipient: address(superloop),
                    amountOut: supplyAmountWithPremium,
                    amountInMaximum: swapAmount,
                    sqrtPriceLimitX96: 0
                })
            )
        });
        DataTypes.ExecuteSwapParams memory swapParams = DataTypes.ExecuteSwapParams({
            tokenIn: XTZ,
            tokenOut: ST_XTZ,
            amountIn: swapAmount,
            maxAmountIn: swapAmount,
            minAmountOut: supplyAmountWithPremium,
            data: swapParamsData
        });

        moduleExecutionData[2] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(dexModule),
            data: abi.encodeWithSelector(dexModule.execute.selector, swapParams)
        });

        // 1. pass data in flashloan
        bytes memory dataForFlashloan = abi.encode(moduleExecutionData);
        DataTypes.AaveV3FlashloanParams memory flashloanParams = DataTypes.AaveV3FlashloanParams({
            asset: ST_XTZ,
            amount: supplyAmount,
            referralCode: 0,
            callbackExecutionData: dataForFlashloan
        });

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(flashloanModule),
            data: abi.encodeWithSelector(flashloanModule.execute.selector, flashloanParams)
        });

        vm.prank(admin);
        superloop.operate(finalExecutionData);
    }
}
