/**
1. Take a flashloan of net amount of xtz borrowed
2. Send the xtz to the vault
2. repay the xtz borrowed
3. withdraw the stXTZ
4. Send the xtz and stXTZ lying in the vault to the new vault via dex module
5. Deposit stXTZ via the new vault
6. borrow xtz + premium via the new vault
7. Read the balances of all the users and mint exact same number of shares for them
8. Minting of shares take place via the mintShares function open to only the deposit manager
8. Repay the flash loan
 */

// post this action, we move change the deposit manager to the actual deposit manager