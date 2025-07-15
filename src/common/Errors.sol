// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library Errors {
    string public constant INVALID_ADDRESS = "1"; // address must not be 0
    string public constant INVALID_MODULE_NAME = "2"; // module name empty
    string public constant INVALID_AMOUNT = "3"; // amount cannot be 0
    string public constant INSUFFICIENT_SHARE_AMOUNT = "4"; // share amount requested for withdraw exceeds balance
    string public constant WITHDRAW_REQUEST_ACTIVE = "5"; // one acitve withdraw request already exist
    string public constant INVALID_WITHDRAW_WINDOW_START = "6"; // new start id should be = old end id + 1
    string public constant INVALID_WITHDRAW_WINDO_END = "7"; // new end id should be < current id
    string public constant CALLER_NOT_VAULT = "8"; // the caller of function is not vault
    string public constant INVALID_WITHDRAW_REQUEST_STATE = "9"; // incorrect withdraw request state
}
