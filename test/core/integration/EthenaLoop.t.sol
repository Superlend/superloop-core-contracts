// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";

contract EthenaLoopTest is IntegrationBase {
    DataTypes.WithdrawRequestType requestType = DataTypes.WithdrawRequestType.INSTANT;

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
        assertEq(withdrawManager.vault(), address(superloop));
        assertEq(withdrawManager.asset(), environment.vaultAsset);
        assertEq(withdrawManager.nextWithdrawRequestId(requestType), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.INSTANT), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.PRIORITY), 1);
        assertEq(withdrawManager.nextWithdrawRequestId(DataTypes.WithdrawRequestType.DEFERRED), 1);
    }

    function test_depositAndFullLoop() public {
        uint256 vaultAssetScale = 10 ** environment.vaultAssetDecimals;
        uint256 borrowTokenScale = 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals();

        uint256 depositAmountUnscaled = 100;
        uint256 depositAmount = depositAmountUnscaled * vaultAssetScale;
        uint256 leverage = 5;

        // deposit 100 USDe
        deal(environment.vaultAsset, user1, depositAmount);
        vm.startPrank(user1);
        IERC20(environment.vaultAsset).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();

        uint256 borrowAmount = depositAmountUnscaled * borrowTokenScale * (leverage - 1) + 1 * borrowTokenScale; // +1 to cover the slippage if any
        uint256 flashLoanAmount = depositAmount * (leverage - 1);

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](5);
        // lend, borrow and swap to USDe
        moduleExecutionData[0] = _stakeCall(environment.lendAssets[1], (depositAmount * leverage) / 2);
        moduleExecutionData[1] = _supplyCall(environment.lendAssets[0], type(uint256).max);
        moduleExecutionData[2] = _supplyCall(environment.lendAssets[1], type(uint256).max);
        moduleExecutionData[3] = _borrowCall(environment.borrowAssets[0], borrowAmount);
        moduleExecutionData[4] = _swapCallExactIn(
            environment.borrowAssets[0],
            environment.lendAssets[0],
            borrowAmount,
            flashLoanAmount,
            environment.router,
            USDC_USDE_POOL_FEE,
            block.timestamp + 100
        );

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] =
            _morphoFlashloanCall(environment.lendAssets[0], flashLoanAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] =
            _resolveDepositRequestsCall(environment.vaultAsset, depositAmount, abi.encode(intermediateExecutionData));

        vm.prank(admin);
        superloop.operate(finalExecutionData);

        uint256 totalAssets = superloop.totalAssets();
        uint256 borrowBalance = IERC20(environment.borrowAssets[0]).balanceOf(address(superloop));
        uint256 lendBalance = IERC20(environment.lendAssets[0]).balanceOf(address(superloop));
        uint256 stakedBalance = IERC20(environment.lendAssets[1]).balanceOf(address(superloop));

        assertApproxEqAbs(totalAssets, depositAmount, 1 * vaultAssetScale);
        assertEq(borrowBalance, 0);

        console.log("totalAssets", totalAssets);
        console.log("lendBalance", lendBalance);
        console.log("stakedBalance", stakedBalance);

        (uint256 currentSupply,,,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.lendAssets[0], address(superloop));
        (uint256 currentStakedSupply,,,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.lendAssets[1], address(superloop));

        (,, uint256 currentBorrowBalance,,,,,,) = IPoolDataProvider(environment.poolDataProvider)
            .getUserReserveData(environment.borrowAssets[0], address(superloop));

        console.log("currentSupply", currentSupply);
        console.log("currentStakedSupply", currentStakedSupply);
        console.log("currentBorrowBalance", currentBorrowBalance);
    }
}
