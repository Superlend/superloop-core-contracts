// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

/**
 * @title Errors
 * @author Superlend
 * @notice Library containing all error constants used throughout the Superloop protocol
 * @dev Centralized error definitions for consistent error handling across contracts
 */
library Errors {
    string public constant INVALID_ADDRESS = "1"; // address must not be 0
    string public constant INVALID_MODULE_NAME = "2"; // module name empty
    string public constant INVALID_AMOUNT = "3"; // amount cannot be 0
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
    string public constant SUPPLY_CAP_EXCEEDED = "21"; // supply cap exceeded
    string public constant INVALID_SHARES_AMOUNT = "22"; // shares amount cannot be 0
    string public constant INSUFFICIENT_BALANCE = "23"; // insufficient balance
    string public constant CALLER_NOT_PRIVILEGED = "24"; // the caller of function is not privileged
    string public constant NOT_IN_EXECUTION_CONTEXT = "25"; // the caller of function is not in execution context
    string public constant MODULE_NOT_REGISTERED = "26"; // module is not registered
    string public constant CALLBACK_HANDLER_NOT_FOUND = "27"; // callback handler not found
    string public constant CALLER_NOT_SELF = "28"; // the caller of function is not self
    string public constant CALLER_NOT_VAULT_ADMIN = "29"; // the caller of function is not vault admin
    string public constant INVALID_SKIM_ASSET = "30"; // invalid asset
    string public constant VAULT_NOT_WHITELISTED = "31"; // vault is not whitelisted
    string public constant TOKEN_NOT_WHITELISTED = "32"; // token is not whitelisted
    string public constant INSTANT_WITHDRAW_NOT_ENABLED = "33"; // instant withdraw is not enabled
    string public constant WITHDRAW_REQUEST_UNCLAIMED = "34"; // withdraw request is unclaimed
    string public constant INVALID_CASH_RESERVE = "35"; // invalid cash reserve
    string public constant INSUFFICIENT_CASH_SHORTFALL = "36"; // insufficient cash shortfall
    string public constant DEPOSIT_REQUEST_ACTIVE = "37"; // deposit request is active
    string public constant DEPOSIT_REQUEST_ALREADY_CANCELLED = "38"; // deposit request already cancelled
    string public constant CALLER_NOT_DEPOSIT_REQUEST_OWNER = "39"; // the caller of function is not the owner of the deposit request
    string public constant DEPOSIT_REQUEST_ALREADY_PROCESSED = "40"; // deposit request already processed
    string public constant INVALID_ASSET = "41"; // invalid asset
    string public constant CALLER_NOT_DEPOSIT_MANAGER = "42"; // the caller of function is not deposit manager
    string public constant DEPOSIT_REQUEST_NOT_FOUND = "43"; // deposit request not found
    string public constant CANNOT_CLAIM_ZERO_AMOUNT = "44"; // cannot claim zero amount
    string public constant CALLER_NOT_WITHDRAW_MANAGER = "45"; // the caller of function is not withdraw manager
    string public constant CALLER_NOT_VAULT_OPERATOR_OR_VAULT_ADMIN = "46"; // the caller of function is not vault operator
    string public constant VAULT_PAUSED = "47"; // vault is paused
    string public constant VAULT_FROZEN = "48"; // vault is frozen
    string public constant DEPOSIT_MANAGER_NOT_WHITELISTED = "49"; // deposit manager is not whitelisted
    string public constant FALLBACK_HANDLER_NOT_FOUND = "50"; // fallback handler not found
    string public constant INVALID_FALLBACK_DATA = "51"; // invalid fallback data

    // Preliquidation
    string public constant PRELIQUIDATION_PRELTV_TOO_HIGH = "52"; // preltv is too high
    string public constant PRELIQUIDATION_LCF_DECREASING = "53"; // lcf is decreasing
    string public constant PRELIQUIDATION_LCF_TOO_HIGH = "54"; // lcf is too high
    string public constant PRELIQUIDATION_LIF_TOO_LOW = "55"; // lif is too low
    string public constant PRELIQUIDATION_LIF_DECREASING = "56"; // lif is decreasing
    string public constant PRELIQUIDATION_LIF_TOO_HIGH = "57"; // lif is too high
    string public constant PRELIQUIDATION_INVALID_ID = "58"; // id is invalid
    string public constant PRELIQUIDATION_INVALID_USER = "59"; // user is invalid
    string public constant PRELIQUIDATION_POSSIBLE_BAD_DEBT = "60"; // possible bad debt
    string public constant PRELIQUIDATION_NOT_IN_PRELIQUIDATION_STATE = "61"; // not in preliquidation state

    // Aave V3 Preliquidation
    string public constant AAVE_V3_PRELIQUIDATION_INVALID_EMODE_CATEGORY = "62"; // reserve is not in the correct emode category
    string public constant AAVE_V3_PRELIQUIDATION_INVALID_LLTV = "63"; // lltv is invalid

    // Superloop
    string public constant VAULT_ALREADY_SEEDED = "64"; // vault already seeded
    string public constant INVALID_INSTANT_WITHDRAW_FEE = "65"; // instant withdraw fee is greater than max instant withdraw fee
}
