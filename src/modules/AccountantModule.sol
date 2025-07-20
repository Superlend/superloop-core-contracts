// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract SuperloopAccountantAaveV3Module {
    // get total assets for the contract
    function getTotalAssets() public view returns (uint256) {
        // get poolDataProvider from poolAddressesProvider
        // read the lend amount from lendAssets
        // read the borrow amount from borrowAssets
        // get price oracle from poolAddressesProvider
        // read the oracle price of lend and borrow assets
        // get the oraclePrice standard and convert all one standard
        // current total assets = lend amount - borrow amount + balanceOf(this)
        // return the current total assets
    }

    // realize the performance fee for the user
}
