// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MigrationHelper} from "../src/helpers/MigrationHelper.sol";

contract DeployMigration is Script {
    address public deployer;
    uint256 public deployerPvtKey;

    address public AAVE_V3_POOL_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    address public REPAY_MODULE = 0x9AF8cCabC21ff594dA237f9694C4A9C6123480c6;
    address public WITHDRAW_MODULE = 0x1f5Ba080B9E5705DA47212167cA44611F78DB130;
    address public DEPOSIT_MODULE = 0x66e82124412C61D7fF90ACFBa82936DD037D737E;
    address public BORROW_MODULE = 0x3de57294989d12066a94a8A16E977992F3cF8433;
    address public DEX_MODULE = 0x38F5efC1267F6103c9b0FE802E1731E245f09Cd0;
    address public constant USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;

    function setUp() public {
        vm.createSelectFork("etherlink");
        deployerPvtKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPvtKey);
    }

    function run() public returns (address) {
        vm.startBroadcast(deployerPvtKey);

        MigrationHelper migrationHelper = new MigrationHelper(
            AAVE_V3_POOL_ADDRESSES_PROVIDER,
            REPAY_MODULE,
            WITHDRAW_MODULE,
            DEPOSIT_MODULE,
            BORROW_MODULE,
            DEX_MODULE,
            USDC
        );

        vm.stopBroadcast();

        return address(migrationHelper);
    }
}
