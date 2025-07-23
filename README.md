# Superloop Protocol Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Module System](#module-system)
5. [User Guide](#user-guide)
6. [Developer Guide](#developer-guide)
7. [Security Considerations](#security-considerations)
8. [Audit Considerations](#audit-considerations)
9. [Integration Examples](#integration-examples)
10. [Testing](#testing)
11. [Deployment](#deployment)

## Overview

**Superloop** is a sophisticated DeFi yield vault protocol that implements ERC4626 standards with advanced modular architecture for automated yield generation and leverage strategies. The protocol enables users to deposit assets and earn optimized yields through Aave V3 integration and automated rebalancing strategies.

### Key Features

- **ERC4626 Compliant**: Standard vault interface for seamless integration
- **Modular Architecture**: Pluggable modules for different DeFi protocols
- **Advanced Yield Strategies**: Leverage farming with automated rebalancing
- **Flashloan Integration**: Efficient position management through flashloans
- **Performance Fee System**: Sustainable fee structure for protocol maintenance
- **Risk Management**: Supply caps, withdrawal queuing, and privileged controls

### Protocol Benefits

- **Capital Efficiency**: Leverage strategies for enhanced yield generation
- **Automation**: Automated rebalancing reduces manual intervention
- **Composability**: Modular design enables easy integration with new protocols
- **Risk Control**: Multiple layers of risk management and safety mechanisms
- **Transparency**: Clear fee structure and position tracking

## Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Superloop Protocol                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐ │
│  │   User Layer    │    │   Vault Layer    │    │  Module     │ │
│  │                 │    │                  │    │  Layer      │ │
│  │ • Depositors    │◄──►│ • Superloop      │◄──►│ • Aave V3   │ │
│  │ • Withdrawals   │    │ • Accountant     │    │ • DEX       │ │
│  │ • Transfers     │    │ • WithdrawMgr    │    │ • Flashloan │ │
│  └─────────────────┘    └──────────────────┘    └─────────────┘ │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐ │
│  │   Registry      │    │   Storage        │    │  External   │ │
│  │   Layer         │    │   Layer          │    │  Protocols  │ │
│  │                 │    │                  │    │             │ │
│  │ • Module        │    │ • State          │    │ • Aave V3   │ │
│  │   Registry      │    │   Management     │    │ • Uniswap   │ │
│  │ • Whitelisting  │    │ • Access Control │    │ • Other DEX │ │
│  └─────────────────┘    └──────────────────┘    └─────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Core Contract Relationships

```
Superloop (Main Vault)
├── AccountantAaveV3 (Asset Tracking)
├── WithdrawManager (Withdrawal Handling)
├── ModuleRegistry (Module Management)
├── AaveV3 Modules (Lending/Borrowing)
├── UniversalDexModule (Trading)
└── FlashloanModule (Position Management)
```

## Core Components

### 1. Superloop (Main Vault)

**File**: `src/core/Superloop/Superloop.sol`

The main vault contract that implements ERC4626 standards and orchestrates all operations.

#### Key Functions

```solidity
// Initialize the vault with configuration
function initialize(DataTypes.VaultInitData memory data) public initializer

// Execute module operations (admin only)
function operate(DataTypes.ModuleExecutionData[] memory moduleExecutionData) external onlyVaultAdmin

// Handle callback operations
fallback(bytes calldata) external returns (bytes memory)
```

#### Storage Structure

```solidity
struct SuperloopState {
    uint256 supplyCap;                    // Maximum vault capacity
    address superloopModuleRegistry;      // Module registry address
    mapping(address => bool) registeredModules;  // Whitelisted modules
    mapping(bytes32 => address) callbackHandlers; // Flashloan callbacks
}
```

### 2. AccountantAaveV3

**File**: `src/core/Accountant/AccountantAaveV3.sol`

Tracks total assets across all Aave V3 positions and calculates performance fees.

#### Key Functions

```solidity
// Get total assets across all positions
function getTotalAssets() public view returns (uint256)

// Calculate performance fee
function getPerformanceFee(uint256 totalShares, uint256 exchangeRate, uint8 decimals) 
    public view onlyVault returns (uint256)

// Set last realized fee exchange rate
function setLastRealizedFeeExchangeRate(uint256 lastRealizedFeeExchangeRate_) public onlyVault
```

#### Asset Calculation Logic

```solidity
// Calculate total assets in base asset terms
uint256 positiveBalance = 0;  // Lending positions
uint256 negativeBalance = 0;  // Borrowing positions

// Sum all lending positions
for (uint256 i; i < lendAssets.length; i++) {
    uint256 balance = getATokenBalance(lendAssets[i]);
    uint256 price = getAssetPrice(lendAssets[i]);
    positiveBalance += (balance * price * commonDecimalFactor) / assetDecimals;
}

// Sum all borrowing positions
for (uint256 i; i < borrowAssets.length; i++) {
    uint256 debt = getVariableDebt(borrowAssets[i]);
    uint256 price = getAssetPrice(borrowAssets[i]);
    negativeBalance += (debt * price * commonDecimalFactor) / assetDecimals;
}

return (positiveBalance - negativeBalance) / baseAssetPrice;
```

### 3. WithdrawManager

**File**: `src/core/WithdrawManager/WithdrawManager.sol`

Manages withdrawal requests with queuing system for large withdrawals.

#### Withdrawal States

```solidity
enum WithdrawRequestState {
    NOT_EXIST,      // Request does not exist
    CLAIMED,        // Request has been claimed
    UNPROCESSED,    // Request is pending processing
    CLAIMABLE,      // Request is ready to be claimed
    CANCELLED       // Request has been cancelled
}
```

#### Key Functions

```solidity
// Request withdrawal (queued)
function requestWithdraw(uint256 shares) external

// Cancel withdrawal request
function cancelWithdrawRequest(uint256 id) external nonReentrant

// Resolve withdrawal requests (vault admin)
function resolveWithdrawRequests(uint256 resolvedIdLimit) external onlyVault

// Claim resolved withdrawal
function withdraw() external nonReentrant

// Instant withdrawal (if enabled)
function withdrawInstant(uint256 shares, bytes memory instantWithdrawData) 
    external nonReentrant returns (uint256)
```

### 4. ModuleRegistry

**File**: `src/core/ModuleRegistry/ModuleRegistry.sol`

Manages whitelisting of approved modules for security.

```solidity
// Set module in registry (owner only)
function setModule(string memory name, address module) external onlyOwner
```

## Module System

### Module Types

#### 1. Aave V3 Action Modules

**Base**: `src/modules/AaveV3ActionModule.sol`

All Aave V3 modules inherit from this base contract.

```solidity
abstract contract AaveV3ActionModule {
    IPoolAddressesProvider public immutable poolAddressesProvider;
    uint256 public constant INTEREST_RATE_MODE = 2; // Variable rate
    
    function execute(DataTypes.AaveV3ActionParams memory params) external virtual;
}
```

**Specific Modules**:
- `AaveV3SupplyModule.sol` - Supply assets to Aave V3
- `AaveV3BorrowModule.sol` - Borrow assets from Aave V3
- `AaveV3WithdrawModule.sol` - Withdraw supplied assets
- `AaveV3RepayModule.sol` - Repay borrowed assets
- `AaveV3EmodeModule.sol` - Set eMode categories

#### 2. UniversalDexModule

**File**: `src/modules/UniversalDexModule.sol`

Executes swaps across multiple DEX protocols.

```solidity
// Execute swap within execution context
function execute(DataTypes.ExecuteSwapParams memory params) 
    external onlyExecutionContext returns (uint256)

// Execute swap and transfer result
function executeAndExit(DataTypes.ExecuteSwapParams memory params, address to)
    external nonReentrant returns (uint256)
```

#### 3. AaveV3FlashloanModule

**File**: `src/modules/AaveV3FlashloanModule.sol`

Executes flashloan operations for position management.

```solidity
function execute(DataTypes.AaveV3FlashloanParams memory params) 
    external onlyExecutionContext
```

### Module Execution Flow

```
1. Vault Admin calls operate()
2. Execution context begins
3. For each module:
   - Verify module is registered
   - Execute via CALL or DELEGATECALL
   - Handle callbacks if needed
4. Execution context ends
```

## User Guide

### For Vault Users

#### 1. Depositing Assets

```solidity
// Approve tokens
IERC20(asset).approve(vaultAddress, amount);

// Deposit assets
uint256 shares = vault.deposit(amount, receiver);

// Or mint shares directly
uint256 assets = vault.mint(shares, receiver);
```

#### 2. Withdrawing Assets

**Standard Withdrawal**:
```solidity
// Request withdrawal (queued)
vault.requestWithdraw(shares);

// Check status
WithdrawRequestState state = withdrawManager.getWithdrawRequestState(requestId);

// Claim when ready
withdrawManager.withdraw();
```

**Instant Withdrawal** (if enabled):
```solidity
uint256 amount = withdrawManager.withdrawInstant(shares, instantWithdrawData);
```

#### 3. Checking Positions

```solidity
// Get total assets
uint256 totalAssets = vault.totalAssets();

// Get user shares
uint256 shares = vault.balanceOf(user);

// Preview operations
uint256 previewShares = vault.previewDeposit(assets);
uint256 previewAssets = vault.previewRedeem(shares);
```

### For Vault Admins

#### 1. Strategy Execution

```solidity
// Create module execution data
DataTypes.ModuleExecutionData[] memory moduleExecutionData = new DataTypes.ModuleExecutionData[](3);

// Supply assets
moduleExecutionData[0] = DataTypes.ModuleExecutionData({
    executionType: DataTypes.CallType.DELEGATECALL,
    module: address(supplyModule),
    data: abi.encodeWithSelector(supplyModule.execute.selector, supplyParams)
});

// Borrow assets
moduleExecutionData[1] = DataTypes.ModuleExecutionData({
    executionType: DataTypes.CallType.DELEGATECALL,
    module: address(borrowModule),
    data: abi.encodeWithSelector(borrowModule.execute.selector, borrowParams)
});

// Execute strategy
vault.operate(moduleExecutionData);
```

#### 2. Risk Management

```solidity
// Set supply cap
vault.setSupplyCap(newCap);

// Add privileged addresses
vault.setPrivilegedAddress(address, true);

// Skim excess tokens
vault.skim(tokenAddress);
```

## Developer Guide

### Contract Development

#### 1. Creating a New Module

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AaveV3ActionModule} from "./AaveV3ActionModule.sol";
import {DataTypes} from "../common/DataTypes.sol";

contract CustomModule is AaveV3ActionModule {
    event CustomActionExecuted(address indexed asset, uint256 amount);
    
    constructor(address poolAddressesProvider_) 
        AaveV3ActionModule(poolAddressesProvider_) {}
    
    function execute(DataTypes.AaveV3ActionParams memory params) 
        external override onlyExecutionContext {
        // Custom logic here
        emit CustomActionExecuted(params.asset, params.amount);
    }
}
```

#### 2. Integration with Vault

```solidity
// 1. Deploy module
CustomModule module = new CustomModule(poolAddressesProvider);

// 2. Register in module registry
moduleRegistry.setModule("customModule", address(module));

// 3. Register with vault
vault.setRegisteredModule(address(module), true);

// 4. Execute
DataTypes.ModuleExecutionData memory executionData = DataTypes.ModuleExecutionData({
    executionType: DataTypes.CallType.DELEGATECALL,
    module: address(module),
    data: abi.encodeWithSelector(module.execute.selector, params)
});

vault.operate([executionData]);
```

#### 3. Storage Patterns

The protocol uses diamond storage pattern for upgradeable contracts:

```solidity
library CustomStorage {
    struct CustomState {
        // State variables
    }
    
    bytes32 private constant STORAGE_SLOT = 
        keccak256("custom.storage.location");
    
    function getStorage() internal pure returns (CustomState storage $) {
        assembly {
            $.slot := STORAGE_SLOT
        }
    }
}
```

### Testing

#### 1. Unit Testing

```solidity
function test_Deposit() public {
    vm.startPrank(user);
    deal(asset, user, amount);
    IERC20(asset).approve(address(vault), amount);
    
    uint256 shares = vault.deposit(amount, user);
    assertGt(shares, 0);
    assertEq(vault.balanceOf(user), shares);
    vm.stopPrank();
}
```

#### 2. Integration Testing

```solidity
function test_LeverageStrategy() public {
    // Setup initial deposit
    _initialDeposit();
    
    // Execute leverage strategy
    DataTypes.ModuleExecutionData[] memory executionData = new DataTypes.ModuleExecutionData[](3);
    executionData[0] = _flashloanCall(asset, amount, callbackData);
    executionData[1] = _supplyCall(asset, amount);
    executionData[2] = _borrowCall(asset, amount);
    
    vm.prank(admin);
    vault.operate(executionData);
    
    // Verify positions
    assertGt(vault.totalAssets(), initialAssets);
}
```

## Security Considerations

### Access Control

#### 1. Role-Based Access

```solidity
// Vault Admin
modifier onlyVaultAdmin() {
    require(msg.sender == vaultAdmin, Errors.CALLER_NOT_VAULT_ADMIN);
    _;
}

// Privileged Addresses
modifier onlyPrivileged() {
    require(privilegedAddresses[msg.sender], Errors.CALLER_NOT_PRIVILEGED);
    _;
}

// Execution Context
modifier onlyExecutionContext() {
    require(SuperloopStorage.isInExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
    _;
}
```

#### 2. Module Whitelisting

```solidity
// Only whitelisted modules can be executed
if (!SuperloopStorage.getSuperloopStorage().registeredModules[module]) {
    revert(Errors.MODULE_NOT_REGISTERED);
}
```

### Reentrancy Protection

```solidity
// NonReentrant modifier on critical functions
function withdraw() external nonReentrant {
    // Withdrawal logic
}

function cancelWithdrawRequest(uint256 id) external nonReentrant {
    // Cancellation logic
}
```

### Input Validation

```solidity
// Amount validation
require(amount > 0, Errors.INVALID_AMOUNT);

// Address validation
require(address != address(0), Errors.INVALID_ADDRESS);

// Supply cap validation
require(totalAssets + amount <= supplyCap, Errors.SUPPLY_CAP_EXCEEDED);
```

### Flashloan Security

```solidity
// Callback handler verification
address handler = callbackHandlers[keccak256(abi.encodePacked(msg.sender, msg.sig))];
require(handler != address(0), Errors.CALLBACK_HANDLER_NOT_FOUND);

// Execution context validation
require(SuperloopStorage.isInExecutionContext(), Errors.NOT_IN_EXECUTION_CONTEXT);
```

## Audit Considerations

### Critical Areas for Review

#### 1. Module Execution

- **Module whitelisting**: Ensure only approved modules can be executed
- **Execution context**: Verify proper context management
- **Callback handling**: Review flashloan callback security
- **Delegate calls**: Audit delegate call usage and storage conflicts

#### 2. Asset Management

- **Total assets calculation**: Verify accuracy across all positions
- **Performance fee calculation**: Check for precision loss and edge cases
- **Exchange rate manipulation**: Review potential manipulation vectors
- **Slippage protection**: Ensure proper slippage controls in swaps

#### 3. Withdrawal System

- **Queue management**: Verify withdrawal request ordering
- **State transitions**: Check for invalid state transitions
- **Instant withdrawal**: Review instant withdrawal security
- **Cancellation logic**: Ensure proper cancellation handling

#### 4. Access Control

- **Admin privileges**: Review admin function access
- **Privileged addresses**: Check privileged address management
- **Module registration**: Verify module registration security
- **Emergency controls**: Review emergency pause mechanisms

### Known Limitations

1. **Centralization Risk**: Vault admin has significant control over strategy execution
2. **Oracle Dependencies**: Relies on Aave V3 price oracles for asset valuation
3. **Liquidation Risk**: Leverage strategies carry liquidation risk
4. **Gas Costs**: Complex operations may have high gas costs
5. **Slippage**: Large trades may experience significant slippage

### Recommendations

1. **Multi-sig Admin**: Implement multi-signature for admin functions
2. **Circuit Breakers**: Add emergency pause mechanisms
3. **Gradual Upgrades**: Implement timelock for critical parameter changes
4. **Insurance**: Consider insurance mechanisms for user funds
5. **Monitoring**: Implement comprehensive monitoring and alerting

## Integration Examples

### 1. Leverage Strategy (7x)

```solidity
function executeLeverageStrategy() external onlyVaultAdmin {
    // 1. Flashloan stXTZ
    DataTypes.AaveV3FlashloanParams memory flashloanParams = DataTypes.AaveV3FlashloanParams({
        asset: ST_XTZ,
        amount: 7 * STXTZ_SCALE,
        referralCode: 0,
        callbackExecutionData: abi.encode(createLeverageExecutionData())
    });
    
    DataTypes.ModuleExecutionData[] memory executionData = new DataTypes.ModuleExecutionData[](1);
    executionData[0] = DataTypes.ModuleExecutionData({
        executionType: DataTypes.CallType.DELEGATECALL,
        module: address(flashloanModule),
        data: abi.encodeWithSelector(flashloanModule.execute.selector, flashloanParams)
    });
    
    vault.operate(executionData);
}

function createLeverageExecutionData() internal view returns (DataTypes.ModuleExecutionData[] memory) {
    DataTypes.ModuleExecutionData[] memory data = new DataTypes.ModuleExecutionData[](3);
    
    // Supply stXTZ
    data[0] = _supplyCall(ST_XTZ, 7 * STXTZ_SCALE);
    
    // Borrow XTZ
    data[1] = _borrowCall(XTZ, 6 * XTZ_SCALE);
    
    // Swap XTZ for stXTZ
    data[2] = _swapCallExactOut(XTZ, ST_XTZ, 7 * XTZ_SCALE, 7 * STXTZ_SCALE, ROUTER, FEE);
    
    return data;
}
```

### 2. Rebalancing Strategy

```solidity
function rebalanceToTargetLeverage(uint256 targetLeverage) external onlyVaultAdmin {
    uint256 currentLeverage = calculateCurrentLeverage();
    
    if (currentLeverage > targetLeverage) {
        // Decrease leverage
        executeDeleverageStrategy(currentLeverage - targetLeverage);
    } else if (currentLeverage < targetLeverage) {
        // Increase leverage
        executeLeverageStrategy(targetLeverage - currentLeverage);
    }
}
```

### 3. Yield Optimization

```solidity
function optimizeYield() external onlyVaultAdmin {
    // 1. Check current yields across protocols
    uint256 aaveYield = getAaveYield();
    uint256 compoundYield = getCompoundYield();
    
    // 2. Rebalance to highest yielding protocol
    if (aaveYield > compoundYield) {
        rebalanceToAave();
    } else {
        rebalanceToCompound();
    }
}
```

## Testing

### Test Structure

```
test/
├── core/
│   ├── Superloop.t.sol          # Main vault tests
│   ├── AccountantAaveV3.t.sol   # Accountant tests
│   ├── ModuleRegistry.t.sol     # Registry tests
│   └── integration/
│       ├── Deposit.t.sol        # Deposit flow tests
│       ├── Withdraw.t.sol       # Withdrawal flow tests
│       └── Rebalance.t.sol      # Strategy tests
├── modules/
│   ├── AaveV3SupplyModule.t.sol # Supply module tests
│   ├── AaveV3BorrowModule.t.sol # Borrow module tests
│   └── UniversalDexModule.t.sol # DEX module tests
└── helpers/
    └── VaultRouter.t.sol        # Router tests
```

### Running Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract SuperloopTest

# Run with verbose output
forge test -vvv

# Run with gas reporting
forge test --gas-report

# Run specific test function
forge test --match-test test_Deposit
```

### Test Coverage

```bash
# Generate coverage report
forge coverage

# Generate coverage report with lcov
forge coverage --report lcov
```

## Deployment

### Deployment Script

```solidity
// script/Deploy.s.sol
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        
        // 1. Deploy modules
        AaveV3SupplyModule supplyModule = new AaveV3SupplyModule(POOL_ADDRESSES_PROVIDER);
        AaveV3BorrowModule borrowModule = new AaveV3BorrowModule(POOL_ADDRESSES_PROVIDER);
        UniversalDexModule dexModule = new UniversalDexModule();
        
        // 2. Deploy core contracts
        SuperloopModuleRegistry moduleRegistry = new SuperloopModuleRegistry();
        AccountantAaveV3 accountant = new AccountantAaveV3();
        WithdrawManager withdrawManager = new WithdrawManager();
        
        // 3. Deploy vault implementation
        Superloop implementation = new Superloop();
        
        // 4. Deploy proxy
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            abi.encodeWithSelector(Superloop.initialize.selector, initData)
        );
        
        // 5. Initialize contracts
        accountant.initialize(accountantInitData);
        withdrawManager.initialize(address(proxy));
        
        // 6. Configure vault
        Superloop vault = Superloop(address(proxy));
        vault.setAccountantModule(address(accountant));
        vault.setWithdrawManagerModule(address(withdrawManager));
        
        vm.stopBroadcast();
    }
}
```

### Deployment Commands

```bash
# Deploy to local network
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet
forge script script/Deploy.s.sol:DeployScript --rpc-url $TESTNET_RPC --private-key $PRIVATE_KEY --broadcast

# Deploy to mainnet
forge script script/Deploy.s.sol:DeployScript --rpc-url $MAINNET_RPC --private-key $PRIVATE_KEY --broadcast
```

### Verification

```bash
# Verify contracts on Etherscan
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> --chain-id 1 --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Support

For questions and support:
- Create an issue on GitHub
- Join our Discord community
- Check our documentation at [docs.superloop.fi](https://docs.superloop.fi)
