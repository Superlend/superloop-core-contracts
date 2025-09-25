// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IntegrationBase} from "./IntegrationBase.sol";
import {DataTypes} from "../../../src/common/DataTypes.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DepositManager} from "../../../src/core/DepositManager/DepositManager.sol";
import {Errors} from "../../../src/common/Errors.sol";
import {MockPreliquidation} from "../../../src/mock/MockPreliquidation.sol";

contract FallbackHandlerTest is IntegrationBase {
    address public preliquidation;
    DataTypes.CallType public callType;
    bytes32 public key;

    function setUp() public override {
        super.setUp();
        callType = DataTypes.CallType.DELEGATECALL;

        preliquidation = address(new MockPreliquidation());

        key =
            keccak256(abi.encodePacked(abi.encodeWithSelector(MockPreliquidation.preliquidate.selector), id, callType));
        vm.startPrank(admin);
        superloop.setFallbackHandler(key, preliquidation);
        vm.stopPrank();
    }

    function test_fallbackHandler() public {
        assertEq(superloop.fallbackHandler(key), preliquidation);

        // make a call to superloop with context of IPreliquidation.preliquidate
        MockPreliquidation(address(superloop)).preliquidate(id, callType, "");

        // this should not revert, not reverting means the decoding in fallback handler is working correctly
    }
}
