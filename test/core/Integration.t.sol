// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// DEPOSIT FLOW
// deposit by few different users a total of 1 xtz

// REBALANCE FLOW
// do the rebalance such that we achieve a leverage of 7x

// UPDATE REBALANCE FLOW
// deposit 1 more xtz
// rebalance ie. achieve the leverage of 7x again which would have been disturbed by new deposits

// REBALANCE TO DELEVERAGE
// reduce leverage from 7x to 5x

// INSTANT WITHDRAW FLOW
// withdraw some token via the instant method

// WITHDRAW REQUEST FLOW
// make a withdraw request, process with via de leveraging
// make withdraw request claimable

import {console} from "forge-std/console.sol";
import {TestBase} from "./TestBase.sol";

contract IntegrationTest is TestBase {}
