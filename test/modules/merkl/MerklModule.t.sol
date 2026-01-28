// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../../core/TestBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DepositManager} from "../../../src/core/DepositManager/DepositManager.sol";
import {console} from "forge-std/Test.sol";
import {Errors} from "../../../src/common/Errors.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IDistributor} from "../../../src/modules/merkl/IDistributor.sol";

contract MerklModuleTest is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;
    IDistributor public distributor;
    address public user;

    uint256 public AMOUNT;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](1);
        modules[0] = address(merklModule);

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

        distributor = IDistributor(environment.distributor);

        user = makeAddr("user");
        vm.label(user, "user");
        vm.label(address(superloop), "superloop");

        AMOUNT = 1000 * 10 ** environment.vaultAssetDecimals;
        address distributorAdmin = 0x435046800Fb9149eE65159721A92cB7d50a7534b;

        // set the root of distributor as hash of vault asset
        deal(environment.vaultAsset, environment.distributor, AMOUNT);
        bytes32 root = keccak256(abi.encode(address(superloop), environment.vaultAsset, AMOUNT));
        bytes32 ipfsHash = bytes32(0);

        vm.prank(distributorAdmin);
        distributor.updateTree(IDistributor.MerkleTree(root, ipfsHash));

        vm.warp(block.timestamp + 86400);
    }

    function test_claim() public {
        DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](1);
        address[] memory users = new address[](1);
        users[0] = address(superloop);
        address[] memory tokens = new address[](1);
        tokens[0] = environment.vaultAsset;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT;
        bytes32[][] memory proofs = new bytes32[][](1);

        moduleExecutionData[0] = DataTypes.ModuleExecutionData({
            executionType: DataTypes.CallType.DELEGATECALL,
            module: address(merklModule),
            data: abi.encodeWithSelector(
                merklModule.execute.selector,
                DataTypes.MerklClaimParams({users: users, tokens: tokens, amounts: amounts, proofs: proofs})
            )
        });

        vm.prank(admin);
        superloop.operate(moduleExecutionData);

        assertEq(IERC20(environment.vaultAsset).balanceOf(address(superloop)), AMOUNT);
    }
}
