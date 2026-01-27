// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../../core/TestBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMorphoFlashLoanCallback} from "morpho-blue/interfaces/IMorphoCallbacks.sol";
import {MorphoFlashloanModule} from "../../../src/modules/morpho/MorphoFlashloanModule.sol";

contract MorphoFlashloanModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    address public user;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](1);
        modules[0] = address(morphoFlashloanModule);

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

        bytes32 key =
            keccak256(abi.encodePacked(environment.morpho, IMorphoFlashLoanCallback.onMorphoFlashLoan.selector));
        superloop.setCallbackHandler(key, address(morphoCallbackHandler));
        vm.stopPrank();
        user = makeAddr("user");

        vm.label(user, "user");
        vm.label(address(superloop), "superloop");
    }

    function test_FlashloanBasicFlow() public {
        vm.startPrank(environment.vaultAssetWhale);
        IERC20(environment.vaultAsset).transfer(address(superloop), 1000 * 10 ** environment.vaultAssetDecimals);
        vm.stopPrank();

        // Arrange
        uint256 flashloanAmount = 1000 * 10 ** environment.vaultAssetDecimals; // 1000 vaultAsset

        // Create flashloan params
        DataTypes.MorphoFlashloanParams memory flashloanParams = DataTypes.MorphoFlashloanParams({
            asset: environment.vaultAsset,
            amount: flashloanAmount,
            callbackExecutionData: "" // No additional execution data for simple return
        });

        // Create module execution data
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(morphoFlashloanModule),
            data: abi.encodeWithSelector(morphoFlashloanModule.execute.selector, flashloanParams)
        });

        // Act
        vm.prank(admin);
        // catch event MorphoFlashloanExecuted
        vm.expectEmit();
        emit MorphoFlashloanModule.MorphoFlashloanExecuted(environment.vaultAsset, flashloanAmount, address(superloop));
        superloop.operate(moduleExecutionData);
    }
}
