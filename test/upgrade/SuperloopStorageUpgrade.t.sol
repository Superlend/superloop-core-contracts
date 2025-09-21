// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {TestBase} from "./TestBase.sol";
import {console} from "forge-std/console.sol";
import {SuperloopStorage} from "../../src/core/lib/SuperloopStorage.sol";
import {Superloop} from "../../src/core/Superloop/Superloop.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {IFlashLoanSimpleReceiver} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SuperloopStorageUpgradeTest is TestBase {
    address testUser1;
    address testUser2;
    address testUser3;
    address testUser4;

    ProxyAdmin public superloopProxyAdmin;

    function setUp() public override {
        super.setUp();

        testUser1 = 0x11fC7853944570C1F9D9EBE7Ac24e2FeFddf0314;
        testUser2 = 0x5d8809340760b1bB54642BE91Bb5A2871C0d7a10;
        testUser3 = 0x703EE58AC2bbC219De04014F3210202C5d82070A;
        testUser4 = 0xa77E705d7166750F53F60ca7e246BAFBE40f5c42;

        superloopProxyAdmin = ProxyAdmin(0x10c351d6087c714e8ddf528B91964c6b846ABc84);

        vm.label(address(superloopProxyAdmin), "superloopProxyAdmin");
        vm.label(address(superloop), "superloopOld");
    }

    struct TestQueryResults {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        uint256 totalAssets;
        uint256[] balances;
        uint256 supplyCap;
        address superloopModuleRegistry;
        bool[] registeredModules;
        address[] callbackHandlers;
        uint256 cashReserve;
        address accountant;
        address withdrawManager;
        address vaultAdmin;
        address treasury;
        bool[] privilegedAddresses;
        address depositManagerModule;
        address vaultOperator;
    }

    function test_SuperloopStorageUpgrade() public {
        /**
         * QUERIES
         *     ERC20/ERC4626 specific data
         *         1. Name
         *         2. Symbol
         *         3. Decimals
         *         4. Total Supply
         *         5. Total assets
         *         6. Balanceof 4 different addresses
         *     SuperloopState data
         *         1. Supply cap
         *         2. superloopModuleRegistry
         *         3. registeredModules
         *         4. callbackHanler
         *         5. cashReserve => only in upgraded version
         *     SuperloopEssentialRoles data
         *         1. accoutant module
         *         2. withdraw manager module
         *         3. vault admin
         *         4. treasury
         *         5. privilegedAddresses
         *         6. deposit manager module => only in upgraded version
         *         7. vault operator => only in upgraded version
         */
        TestQueryResults memory initialResults = _performQueries(false);
        console.log("Initial Results--------------------------------");
        logQueryResults(initialResults);

        // deploy a new implementation of the superloop and call the upgrade function
        Superloop newSuperloopImplementation = new Superloop();

        vm.startPrank(admin);
        superloopProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(superloop)), address(newSuperloopImplementation), ""
        );

        // perform the above queries again
        // compare the results
    }

    function _performQueries(bool isUpgraded) internal view returns (TestQueryResults memory) {
        bytes32 key = keccak256(abi.encodePacked(POOL, IFlashLoanSimpleReceiver.executeOperation.selector));

        TestQueryResults memory results = TestQueryResults({
            name: superloop.name(),
            symbol: superloop.symbol(),
            decimals: superloop.decimals(),
            totalSupply: superloop.totalSupply(),
            totalAssets: superloop.totalAssets(),
            balances: new uint256[](4),
            supplyCap: superloop.supplyCap(),
            superloopModuleRegistry: superloop.superloopModuleRegistry(),
            registeredModules: new bool[](5),
            callbackHandlers: new address[](1),
            cashReserve: isUpgraded ? superloop.cashReserve() : 0,
            accountant: superloop.accountant(),
            withdrawManager: superloop.withdrawManager(),
            vaultAdmin: superloop.vaultAdmin(),
            treasury: superloop.treasury(),
            privilegedAddresses: new bool[](3),
            depositManagerModule: isUpgraded ? superloop.depositManagerModule() : address(0),
            vaultOperator: isUpgraded ? superloop.vaultOperator() : address(0)
        });

        results.balances[0] = superloop.balanceOf(testUser1);
        results.balances[1] = superloop.balanceOf(testUser2);
        results.balances[2] = superloop.balanceOf(testUser3);
        results.balances[3] = superloop.balanceOf(testUser4);

        results.registeredModules[0] = superloop.registeredModule(address(supplyModule));
        results.registeredModules[1] = superloop.registeredModule(address(withdrawModule));
        results.registeredModules[2] = superloop.registeredModule(address(borrowModule));
        results.registeredModules[3] = superloop.registeredModule(address(repayModule));
        results.registeredModules[4] = superloop.registeredModule(address(flashloanModule));

        results.privilegedAddresses[0] = superloop.privilegedAddress(admin);
        results.privilegedAddresses[1] = superloop.privilegedAddress(treasury);
        results.privilegedAddresses[2] = superloop.privilegedAddress(address(withdrawManager));

        results.callbackHandlers[0] = superloop.callbackHandler(key);

        return results;
    }

    function logQueryResults(TestQueryResults memory results) internal pure {
        console.log("ERC20/ERC4626 specific data--------------------------------");
        console.log("Name: %s", results.name);
        console.log("Symbol: %s", results.symbol);
        console.log("Decimals: %s", results.decimals);
        console.log("Total Supply: %s", results.totalSupply);
        console.log("Total Assets: %s", results.totalAssets);
        console.log("Balances: ");
        for (uint256 i = 0; i < results.balances.length; i++) {
            console.log(results.balances[i]);
        }

        console.log("SuperloopState data--------------------------------");
        console.log("Supply Cap: %s", results.supplyCap);
        console.log("Superloop Module Registry: %s", results.superloopModuleRegistry);
        console.log("Cash Reserve: %s", results.cashReserve);
        // log the array of registered modules
        console.log("Registered Modules: ");
        for (uint256 i = 0; i < results.registeredModules.length; i++) {
            console.log(results.registeredModules[i]);
        }
        // log the array of callback handlers
        console.log("Callback Handlers: ");
        for (uint256 i = 0; i < results.callbackHandlers.length; i++) {
            console.log(results.callbackHandlers[i]);
        }

        console.log("SuperloopEssentialRoles data--------------------------------");
        console.log("Accountant Module: %s", results.accountant);
        console.log("Withdraw Manager Module: %s", results.withdrawManager);
        console.log("Vault Admin: %s", results.vaultAdmin);
        console.log("Treasury: %s", results.treasury);
        console.log("Deposit Manager Module: %s", results.depositManagerModule);
        console.log("Vault Operator: %s", results.vaultOperator);
        // log the array of privileged addresses
        console.log("Privileged Addresses: ");
        for (uint256 i = 0; i < results.privilegedAddresses.length; i++) {
            console.log(results.privilegedAddresses[i]);
        }
    }
}
