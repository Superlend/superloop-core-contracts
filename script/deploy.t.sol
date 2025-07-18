// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {UniversalDexModule} from "../src/modules/UniversalDexModule.sol";

contract Deploy is Script {
    address public admin;
    uint256 public deployerPvtKey;

    function setUp() public {
        vm.createSelectFork("etherlink");

        deployerPvtKey = vm.envUint("PRIVATE_KEY");
        admin = vm.addr(deployerPvtKey);
        console.log("admin", admin);
    }

    function run() public {
        vm.startBroadcast(deployerPvtKey);

        UniversalDexModule universalDexModule = new UniversalDexModule();

        console.log("universalDexModule", address(universalDexModule));

        vm.stopBroadcast();
    }
}
