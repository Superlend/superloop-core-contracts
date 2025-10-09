// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../../core/TestBase.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract WrapModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](2);
        modules[0] = address(unwrapModule);
        modules[1] = address(wrapModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "XTZ Vault",
            symbol: "XTZV",
            supplyCap: 100000 * 10 ** 18,
            minimumDepositAmount: 100,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountant: mockModule,
            withdrawManager: mockModule,
            depositManager: mockModule,
            cashReserve: 1000,
            vaultAdmin: admin,
            treasury: treasury,
            vaultOperator: admin
        });
        superloopImplementation = new Superloop();
        proxyAdmin = new ProxyAdmin(address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(superloopImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(payable(address(proxy)));
        vm.stopPrank();

        user = makeAddr("user");
        vm.label(user, "user");
        vm.label(address(superloop), "superloop");
    }

    function test_SupplyBasicFlow() public {
        vm.startPrank(XTZ_WHALE);
        IERC20(XTZ).transfer(address(superloop), 1000 * 10 ** 18);
        vm.stopPrank();

        uint256 supplyAmount = 100 * 10 ** 18;
        _executeUnwrap(supplyAmount);

        // warp
        DataTypes.AaveV3ActionParams memory wrapParams =
            DataTypes.AaveV3ActionParams({asset: XTZ, amount: supplyAmount});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(wrapModule),
            data: abi.encodeWithSelector(wrapModule.execute.selector, wrapParams)
        });

        uint256 currentBalanceWrappedToken = IERC20(XTZ).balanceOf(address(superloop));
        uint256 currentBalanceUnderlyingToken = address(superloop).balance;

        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        uint256 finalBalanceWrappedToken = IERC20(XTZ).balanceOf(address(superloop));
        uint256 finalBalanceUnderlyingToken = address(superloop).balance;

        assertEq(finalBalanceWrappedToken, currentBalanceWrappedToken + supplyAmount);
        assertEq(finalBalanceUnderlyingToken, currentBalanceUnderlyingToken - supplyAmount);
    }

    function _executeUnwrap(uint256 supplyAmount) internal {
        // Create supply params
        DataTypes.AaveV3ActionParams memory unwarpParams =
            DataTypes.AaveV3ActionParams({asset: XTZ, amount: supplyAmount});

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(unwrapModule),
            data: abi.encodeWithSelector(unwrapModule.execute.selector, unwarpParams)
        });

        // current supply
        uint256 currentBalanceWrappedToken = IERC20(XTZ).balanceOf(address(superloop));
        uint256 currentBalanceUnderlyingToken = address(superloop).balance;

        // Act
        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        uint256 finalBalanceWrappedToken = IERC20(XTZ).balanceOf(address(superloop));
        uint256 finalBalanceUnderlyingToken = address(superloop).balance;

        // Assert
        assertEq(finalBalanceWrappedToken, currentBalanceWrappedToken - supplyAmount);
        assertEq(finalBalanceUnderlyingToken, currentBalanceUnderlyingToken + supplyAmount);
    }
}
