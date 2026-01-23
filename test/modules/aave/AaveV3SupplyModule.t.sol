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

contract AaveV3SupplyModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](1);
        modules[0] = address(supplyModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: environment.vaultAsset,
            name: "Vault",
            symbol: "VLT",
            supplyCap: 100000 * 10 ** environment.vaultAssetDecimals,
            minimumDepositAmount: 100,
            instantWithdrawFee: 0,
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
        vm.startPrank(environment.vaultAssetWhale);
        IERC20(environment.vaultAsset).transfer(address(superloop), 1000 * 10 ** environment.vaultAssetDecimals);
        vm.stopPrank();

        // Arrange
        uint256 supplyAmount = 1000 * 10 ** environment.vaultAssetDecimals; // 1000 vaultAsset

        // Create supply params
        DataTypes.AaveV3ActionParams memory supplyParams =
            DataTypes.AaveV3ActionParams({asset: environment.vaultAsset, amount: supplyAmount});

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(supplyModule),
            data: abi.encodeWithSelector(supplyModule.execute.selector, supplyParams)
        });

        // current supply
        (uint256 currentSupply,,,,,,,,) =
            poolDataProvider.getUserReserveData(environment.vaultAsset, address(superloop));
        uint256 currentBalance = IERC20(environment.vaultAsset).balanceOf(address(superloop));

        // Act
        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        // Assert
        (uint256 finalSupply,,,,,,,,) = poolDataProvider.getUserReserveData(environment.vaultAsset, address(superloop));
        uint256 finalBalance = IERC20(environment.vaultAsset).balanceOf(address(superloop));

        assertApproxEqAbs(finalSupply, currentSupply + supplyAmount, 1);
        assertApproxEqAbs(finalBalance, currentBalance - supplyAmount, 1);
    }
}
