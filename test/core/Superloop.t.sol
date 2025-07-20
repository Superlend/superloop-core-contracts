// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {TestBase} from "./TestBase.sol";
import {Superloop} from "../../src/core/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";

contract SuperloopTest is TestBase {
    function setUp() public override {
        super.setUp();

        DataTypes.VaultInitData memory data = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Superloop XTZ-stXTZ",
            symbol: "XTZ-stXTZ",
            supplyCap: 100_000 * 10 ** 18,
            superloopModuleRegistry: address(moduleRegistry),
            modules: new address[](0),
            accountantModule: address(0),
            withdrawManagerModule: address(0),
            vaultAdmin: admin,
            treasury: treasury
        });

        superloop = new Superloop();
        superloop.initialize(data);
    }

    function test_initialize() public {}
}
