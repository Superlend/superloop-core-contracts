// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "../IntegrationBase.sol";
import {DataTypes} from "../../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DepositManager} from "../../../../src/core/DepositManager/DepositManager.sol";
import {console} from "forge-std/Test.sol";

contract DepositManagerTest is IntegrationBase {
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

    function test_initialize() public {
        assertEq(depositManager.vault(), address(superloop));
        assertEq(depositManager.asset(), XTZ);
        assertEq(depositManager.nextDepositRequestId(), 1);
    }

    function test_resolveDepositRequestResolution() public {
        uint256 depositAmount = 100 * XTZ_SCALE;
        _makeDepositRequest(depositAmount, user1, true);

        // // build the operate call
        uint256 supplyAmount = 150 * STXTZ_SCALE;
        uint256 borrowAmount = 60 * XTZ_SCALE;
        uint256 swapAmount = borrowAmount + depositAmount;
        uint256 supplyAmountWithPremium = supplyAmount + (supplyAmount * 1) / 10000;

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);
        moduleExecutionData[0] = _supplyCall(ST_XTZ, supplyAmount);
        moduleExecutionData[1] = _borrowCall(XTZ, borrowAmount);

        moduleExecutionData[2] =
            _swapCallExactOutCurve(XTZ, ST_XTZ, XTZ_STXTZ_POOL, swapAmount, supplyAmountWithPremium, XTZ_STXTZ_SWAP);

        DataTypes.ModuleExecutionData[] memory intermediateExecutionData = new DataTypes.ModuleExecutionData[](1);
        intermediateExecutionData[0] = _flashloanCall(ST_XTZ, supplyAmount, abi.encode(moduleExecutionData));

        DataTypes.ModuleExecutionData[] memory finalExecutionData = new DataTypes.ModuleExecutionData[](1);
        finalExecutionData[0] = _resolveDepositRequestsCall(XTZ, depositAmount, abi.encode(intermediateExecutionData));

        vm.prank(admin);
        superloop.operate(finalExecutionData);
    }

    function test_instantDepositWithLimit() public {}

    function test_resolveDepositRequestWithPartials() public {}

    function test_resolveDepositRequestWithCancellation() public {}

    function _makeDepositRequest(uint256 depositAmount, address user, bool _deal) public {
        if (_deal) {
            deal(XTZ, user, depositAmount);
        }

        vm.startPrank(user);
        IERC20(XTZ).approve(address(depositManager), depositAmount);
        depositManager.requestDeposit(depositAmount, address(0));
        vm.stopPrank();
    }
}
