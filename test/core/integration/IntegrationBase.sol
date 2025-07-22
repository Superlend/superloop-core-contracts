// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {Superloop} from "../../../src/core/Superloop/Superloop.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";

abstract contract IntegrationBase is TestBase {
    Superloop public superloopImplementation;
    ProxyAdmin public proxyAdmin;

    address public constant POOL_CONFIGURATOR = 0x30F6880Bb1cF780a49eB4Ef64E64585780AAe060;
    address public constant POOL_ADMIN = 0x669bd328f6C494949Ed9fB2dc8021557A6Dd005f;

    address public user1;
    address public user2;
    address public user3;

    uint24 public constant XTZ_STXTZ_POOL_FEE = 100; // 0.01%

    uint256 public constant XTZ_SCALE = 10 ** 18;
    uint256 public constant STXTZ_SCALE = 10 ** 6;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(admin);
        _deployModules();

        address[] memory modules = new address[](8);
        modules[0] = address(dexModule);
        modules[1] = address(flashloanModule);
        modules[2] = address(callbackHandler);
        modules[3] = address(emodeModule);
        modules[4] = address(supplyModule);
        modules[5] = address(withdrawModule);
        modules[6] = address(borrowModule);
        modules[7] = address(repayModule);

        DataTypes.VaultInitData memory initData = DataTypes.VaultInitData({
            asset: XTZ,
            name: "XTZ Vault",
            symbol: "XTZV",
            supplyCap: 100000 * 10 ** 18,
            superloopModuleRegistry: address(moduleRegistry),
            modules: modules,
            accountantModule: address(accountantAaveV3),
            withdrawManagerModule: address(withdrawManager),
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

        _deployAccountant(address(superloop));
        _deployWithdrawManager(address(superloop));

        bytes32 key = keccak256(abi.encodePacked(POOL, IFlashLoanSimpleReceiver.executeOperation.selector));
        superloop.setCallbackHandler(key, address(callbackHandler));

        superloop.setAccountantModule(address(accountantAaveV3));
        superloop.setWithdrawManagerModule(address(withdrawManager));

        vm.stopPrank();
        vm.label(address(superloop), "superloop");

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.label(user3, "user3");

        vm.startPrank(XTZ_WHALE);
        IERC20(XTZ).transfer(user1, 100 * 10 ** 18);
        IERC20(XTZ).transfer(user2, 100 * 10 ** 18);
        IERC20(XTZ).transfer(user3, 100 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(POOL_ADMIN);
        IPoolConfigurator(POOL_CONFIGURATOR).setReserveFlashLoaning(ST_XTZ, true);
        vm.stopPrank();
    }
}
