// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../../core/TestBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract ERC4626ModuleTest is TestBase {
    Superloop public superloopImplementation;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](2);
        modules[0] = address(vaultSupplyModule);
        modules[1] = address(vaultWithdrawModule);

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

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(superloopImplementation),
            address(this),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        superloop = Superloop(payable(address(proxy)));
        vm.stopPrank();

        user = makeAddr("user");
        vm.label(user, "user");
        vm.label(address(superloop), "superloop");
    }

    function test_VaultSupply() public {
        if (environment.chainId != 1) return;

        address stakingVault = environment.lendAssets[1];

        deal(environment.vaultAsset, address(superloop), 1000 * 10 ** environment.vaultAssetDecimals);

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(vaultSupplyModule),
            data: abi.encodeWithSelector(
                vaultSupplyModule.execute.selector,
                DataTypes.VaultActionParams({vault: stakingVault, amount: 1000 * 10 ** environment.vaultAssetDecimals})
            )
        });

        uint256 currentBalance = IERC20(stakingVault).balanceOf(address(superloop));

        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        uint256 finalBalance = IERC20(stakingVault).balanceOf(address(superloop));

        assert(finalBalance > currentBalance);
    }

    function test_VaultWithdraw() public {
        if (environment.chainId != 1) return;
        // create supply
        test_VaultSupply();

        address stakingVault = environment.lendAssets[1];
        address underlyingAsset = environment.lendAssets[0];

        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(vaultWithdrawModule),
            data: abi.encodeWithSelector(
                vaultWithdrawModule.execute.selector,
                DataTypes.VaultActionParams({vault: stakingVault, amount: type(uint256).max})
            )
        });

        // expected to revert in this case becase direct withdraw from vault is not allowed for sUSDe
        vm.prank(admin);
        vm.expectRevert();
        superloop.operate(moduleExecutionData);
    }
}
