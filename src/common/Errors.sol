// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library Errors {
    string public constant INVALID_ADDRESS = "1"; // address must not be 0
    string public constant INVALID_MODULE_NAME = "2"; // module name empty
    string public constant INVALID_AMOUNT = "3"; // amount cannot be 0
    string public constant INSUFFICIENT_SHARE_AMOUNT = "4"; // share amount requested for withdraw exceeds balance
    string public constant WITHDRAW_REQUEST_ACTIVE = "5"; // one acitve withdraw request already exist
    string public constant INVALID_WITHDRAW_RESOLVED_START_ID_LIMIT = "6"; // new start id should be = old end id + 1
    string public constant INVALID_WITHDRAW_RESOLVED_END_ID_LIMIT = "7"; // new end id should be < current id
    string public constant CALLER_NOT_VAULT = "8"; // the caller of function is not vault
    string public constant INVALID_WITHDRAW_REQUEST_STATE = "9"; // incorrect withdraw request state
    string public constant INVALID_ASSETS_DISTRIBUTED = "10"; // total assets distributed does not match total assets redeemed
    string public constant WITHDRAW_REQUEST_NOT_FOUND = "11"; // withdraw request not found
    string public constant WITHDRAW_REQUEST_ALREADY_CLAIMED = "12"; // withdraw request already claimed
    string public constant WITHDRAW_REQUEST_NOT_RESOLVED = "13"; // withdraw request not resolved
    string public constant CALLER_NOT_WITHDRAW_REQUEST_OWNER = "14"; // the caller of function is not the owner of the withdraw request
    string public constant INVALID_PERFORMANCE_FEE = "15"; // performance fee is greater than max performance fee
    string public constant INVALID_MODULE = "16"; // module is not whitelisted
    string public constant INVALID_SWAP_DATA = "17"; // invalid swap data
    string public constant INVALID_AMOUNT_IN = "18"; // amount in is greater than max amount in
    string public constant INVALID_AMOUNT_OUT = "19"; // amount out is less than min amount out
    string public constant TRANSFER_NOT_SUPPORTED = "20"; // transfer is not supported
    string public constant SUPPLY_CAP_EXCEEDED = "21"; // supply cap exceeded
    string public constant INVALID_SHARES_AMOUNT = "22"; // shares amount cannot be 0
    string public constant INSUFFICIENT_BALANCE = "23"; // insufficient balance
    string public constant CALLER_NOT_PRIVILEGED = "24"; // the caller of function is not privileged
    string public constant NOT_IN_EXECUTION_CONTEXT = "25"; // the caller of function is not in execution context
    string public constant MODULE_NOT_REGISTERED = "26"; // module is not registered
    string public constant CALLBACK_HANDLER_NOT_FOUND = "27"; // callback handler not found
    string public constant CALLER_NOT_SELF = "28"; // the caller of function is not self
}
