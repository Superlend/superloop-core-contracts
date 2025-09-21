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
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {console} from "forge-std/console.sol";

contract AaveV3BorrowModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](3);
        modules[0] = address(supplyModule);
        modules[1] = address(withdrawModule);
        modules[2] = address(borrowModule);

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
        vm.stopPrank();

        user = makeAddr("user");
        vm.label(user, "user");
        vm.label(address(superloop), "superloop");

        vm.startPrank(POOL_ADMIN);
        IPoolConfigurator(POOL_CONFIGURATOR).setReserveFlashLoaning(ST_XTZ, true);
        IPoolConfigurator(POOL_CONFIGURATOR).setSupplyCap(ST_XTZ, 10000000);
        vm.stopPrank();
    }

    function test_BorrowBasicFlow() public {
        _supply();

        // Arrange
        uint256 borrowAmount = 5 * 10 ** 18; // 5 XTZ

        // Create withdraw params
        DataTypes.AaveV3ActionParams memory borrowParams =
            DataTypes.AaveV3ActionParams({asset: XTZ, amount: borrowAmount});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(borrowModule),
            data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
        });

        (,, uint256 currentBorrow,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        uint256 currentBalance = IERC20(XTZ).balanceOf(address(superloop));

        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        (,, uint256 finalBorrow,,,,,,) = poolDataProvider.getUserReserveData(XTZ, address(superloop));
        uint256 finalBalance = IERC20(XTZ).balanceOf(address(superloop));

        assertTrue(finalBorrow > currentBorrow);
        assertTrue(finalBalance > currentBalance);
    }

    function _supply() internal {
        vm.startPrank(STXTZ_WHALE);
        IERC20(ST_XTZ).transfer(address(superloop), 1000 * 10 ** 6);
        vm.stopPrank();
        uint256 supplyAmount = 10 * 10 ** 6; // 10 ST_XTZ

        DataTypes.AaveV3ActionParams memory supplyParams =
            DataTypes.AaveV3ActionParams({asset: ST_XTZ, amount: supplyAmount});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(supplyModule),
            data: abi.encodeWithSelector(supplyModule.execute.selector, supplyParams)
        });
        vm.prank(admin);
        superloop.operate(moduleExecutionData);
    }
}
