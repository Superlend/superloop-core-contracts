## Change from V1

1. Introduction of cash reserve value, used to allow small instant deposits
2. Deposit manager with queue based system
3. Updated withdraw manager with queue based system + isolated queues
4. Non socializing of entry and exit costs (deposit and withdraw) using exchange rate reset mechanism
5. Allowing whitelisted arbitrary code to be called using fallback handlers
6. System is now pausable and freezable
7. There is new role called vault operator which call the 'operate' function on the vault
8. Vault router has been updated to accomodate the new deposit manager
9. Universal accounant module with plugin system