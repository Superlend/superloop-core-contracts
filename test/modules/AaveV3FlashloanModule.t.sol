// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../core/TestBase.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";
import {Superloop} from "../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AaveV3FlashloanModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](1);
        modules[0] = address(flashloanModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "XTZ Vault",
            symbol: "XTZV",
            supplyCap: 100000 * 10 ** 18,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury
        });
        superloopImplementation = new Superloop();
        proxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(superloopImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(address(proxy));

        bytes32 key = keccak256(abi.encodePacked(POOL, IFlashLoanSimpleReceiver.executeOperation.selector));
        superloop.setCallbackHandler(key, address(callbackHandler));
        vm.stopPrank();
        user = makeAddr("user");

        vm.label(user, "user");
        vm.label(address(superloop), "superloop");
    }

    function test_FlashloanBasicFlow() public {
        vm.startPrank(XTZ_WHALE);
        IERC20(XTZ).transfer(address(superloop), 10 * 10 ** 18);
        vm.stopPrank();

        // Arrange
        uint256 flashloanAmount = 1000 * 10 ** 18; // 1000 XTZ
        uint16 referralCode = 0;

        // Create flashloan params
        DataTypes.AaveV3FlashloanParams memory flashloanParams = DataTypes.AaveV3FlashloanParams({
            asset: XTZ,
            amount: flashloanAmount,
            referralCode: referralCode,
            callbackExecutionData: "" // No additional execution data for simple return
        });

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(flashloanModule),
            data: abi.encodeWithSelector(flashloanModule.execute.selector, flashloanParams)
        });

        // Record initial balances
        uint256 initialXTZBalance = IERC20(XTZ).balanceOf(address(superloop));

        // Act
        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        // Assert
        uint256 finalXTZBalance = IERC20(XTZ).balanceOf(address(superloop));
        assertLt(finalXTZBalance, initialXTZBalance, "Balance should decrease slightly after flashloan due to premium");
    }
}
