// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IRouter} from "../../../src/mock/MockIRouter.sol";
import {IPriceOracleGetter} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract OperateTest is IntegrationBase {
    function setUp() public override {
        super.setUp();

        DataTypes.AaveV3EmodeParams memory params = DataTypes
            .AaveV3EmodeParams({emodeCategory: 3});

        DataTypes.ModuleExecutionData[]
            memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
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
    function test_operate() public {
        address _superloopLive = address(0); // TODO: add this address
        bytes memory data = vm.parseBytes("0x0");

        vm.prank(admin);
        Address.functionCall(_superloopLive, data);
    }
}
