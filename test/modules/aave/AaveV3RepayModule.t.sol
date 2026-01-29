// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../../core/TestBase.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";

contract AaveV3RepayModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](4);
        modules[0] = address(supplyModule);
        modules[1] = address(withdrawModule);
        modules[2] = address(borrowModule);
        modules[3] = address(repayModule);

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

    function test_RepayBasicFlow() public {
        _supply();
        _borrow();

        // Arrange
        uint256 repayAmount = 5 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(); // 5 borrowAsset

        // Create repay params
        DataTypes.AaveV3ActionParams memory repayParams =
            DataTypes.AaveV3ActionParams({asset: environment.borrowAssets[0], amount: repayAmount});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(repayModule),
            data: abi.encodeWithSelector(repayModule.execute.selector, repayParams)
        });

        (,, uint256 currentBorrow,,,,,,) =
            poolDataProvider.getUserReserveData(environment.borrowAssets[0], address(superloop));
        uint256 currentBalance = IERC20(environment.borrowAssets[0]).balanceOf(address(superloop));

        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        (,, uint256 finalBorrow,,,,,,) =
            poolDataProvider.getUserReserveData(environment.borrowAssets[0], address(superloop));
        uint256 finalBalance = IERC20(environment.borrowAssets[0]).balanceOf(address(superloop));

        assertTrue(finalBorrow < currentBorrow);
        assertTrue(finalBalance < currentBalance);
    }

    function _supply() internal {
        vm.startPrank(environment.vaultAssetWhale);
        IERC20(environment.vaultAsset).transfer(address(superloop), 1000 * 10 ** environment.vaultAssetDecimals);
        vm.stopPrank();
        uint256 supplyAmount = 1000 * 10 ** environment.vaultAssetDecimals; // 1000 vaultAsset

        DataTypes.AaveV3ActionParams memory supplyParams =
            DataTypes.AaveV3ActionParams({asset: environment.vaultAsset, amount: supplyAmount});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(supplyModule),
            data: abi.encodeWithSelector(supplyModule.execute.selector, supplyParams)
        });
        vm.prank(admin);
        superloop.operate(moduleExecutionData);
    }

    function _borrow() internal {
        // Arrange
        uint256 borrowAmount = 5 * 10 ** IERC20Metadata(environment.borrowAssets[0]).decimals(); // 5 borrowAsset

        // Create withdraw params
        DataTypes.AaveV3ActionParams memory borrowParams =
            DataTypes.AaveV3ActionParams({asset: environment.borrowAssets[0], amount: borrowAmount});

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(borrowModule),
            data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
        });

        vm.prank(admin);
        superloop.operate(moduleExecutionData);
    }
}
