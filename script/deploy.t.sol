// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
// import {UniversalDexModule} from "../src/modules/UniversalDexModule.sol";
import {MockVault} from "../src/mock/MockVault.sol";
import {MockWithdrawManager} from "../src/mock/MockWithdrawManager.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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

        MockVault mockVault =
            new MockVault(IERC20(0xc9B53AB2679f573e480d01e0f49e2B5CFB7a3EAb), "SuperLoopMockVault", "SLMV");

        MockWithdrawManager mockWithdrawManager = new MockWithdrawManager();

        mockWithdrawManager.initialize(address(mockVault));

        console.log("mockVault", address(mockVault));
        console.log("mockWithdrawManager", address(mockWithdrawManager));

        vm.stopBroadcast();
    }
}
