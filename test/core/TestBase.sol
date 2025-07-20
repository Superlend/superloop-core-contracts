// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Superloop} from "../../src/core/Superloop.sol";
import {DataTypes} from "../../src/common/DataTypes.sol";

contract TestBase is Test {
    address public constant ST_XTZ = 0x0000000000000000000000000000000000000000;
    address public constant XTZ = 0x0000000000000000000000000000000000000000;

    Superloop public superloop;

    function setUp() public virtual {
        vm.createSelectFork("etherlink");

        DataTypes.VaultInitData memory data = DataTypes.VaultInitData({
            asset: XTZ,
            name: "Superloop",
            symbol: "SUPERLOOP",
            supplyCap: 100_000 * 10 ** 18,
            superloopModuleRegistry: address(0),
            modules: new address[](0),
            accountantModule: address(0),
            withdrawManagerModule: address(0),
            vaultAdmin: address(0),
            treasury: address(0)
        });

        superloop = new Superloop();
    }
}
