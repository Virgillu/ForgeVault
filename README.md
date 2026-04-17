[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-black)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FF6B6B)](https://getfoundry.sh/)
[![Tests](https://github.com/Virgillu/ForgeVault/actions/workflows/test.yml/badge.svg)](https://github.com/Virgillu/ForgeVault/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Audit](https://img.shields.io/badge/Audit-Self_Reviewed-blue)](./docs/AUDIT_REPORT.md)

# 🏦 ForgeVault

**A professional-grade ERC-4626 Tokenized Vault with yield harvesting, performance fees, and comprehensive security controls.**

ForgeVault is a production-ready yield-bearing vault that allows users to deposit assets and earn yield through integrated strategies. Built with Foundry and following OpenZeppelin standards.

---

## 🚀 Deployed Contracts (Sepolia Testnet)

| Contract | Address | Status |
|----------|---------|--------|
| MyToken | `0xF16eD8b9E44Fa707901031ACcf4Dd2Dac38C9c10` | [✅ Verified](https://sepolia.etherscan.io/address/0xF16eD8b9E44Fa707901031ACcf4Dd2Dac38C9c10) |
| ForgeVault | `0x610E80Db537f658da8157ACf3d1C7FD141E0Bf16` | [✅ Verified](https://sepolia.etherscan.io/address/0x610E80Db537f658da8157ACf3d1C7FD141E0Bf16) |

### Try it on Sepolia

```bash
# Set your wallet address
export MY_ADDRESS=0xYourWalletAddressHere

# Get test tokens (1000 MTK with 18 decimals)
cast send 0xF16eD8b9E44Fa707901031ACcf4Dd2Dac38C9c10 \
  "mint(address,uint256)" $MY_ADDRESS 1000000000000000000 \
  --rpc-url sepolia

# Approve vault to spend tokens
cast send 0xF16eD8b9E44Fa707901031ACcf4Dd2Dac38C9c10 \
  "approve(address,uint256)" 0x610E80Db537f658da8157ACf3d1C7FD141E0Bf16 1000000000000000000 \
  --rpc-url sepolia

# Deposit to vault
cast send 0x610E80Db537f658da8157ACf3d1C7FD141E0Bf16 \
  "deposit(uint256,address)" 1000000000000000000 $MY_ADDRESS \
  --rpc-url sepolia

# Check your balance
cast call 0x610E80Db537f658da8157ACf3d1C7FD141E0Bf16 \
  "balanceOf(address)" $MY_ADDRESS --rpc-url sepolia

✨ Features

Feature	Description
🏦 ERC-4626 Compliant	Industry standard for tokenized vaults
📈 Yield Harvesting	Automatic yield distribution with configurable fees (max 5%)
🔒 Security First	ReentrancyGuard, AccessControl, Pausable
⛽ Gas Optimized	~132k gas per deposit
🧪 100% Test Coverage	40 passing tests
🔐 Slippage Protection	Built-in front-running protection

📊 Architecture

┌─────────────────────────────────────────────────────────────┐
│                        ForgeVault                            │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │  ERC-4626   │  │ AccessControl│  │  ReentrancyGuard  │  │
│  └─────────────┘  └──────────────┘  └───────────────────┘  │
│                           │                                  │
│  ┌────────────────────────▼────────────────────────────┐    │
│  │                 Yield Mechanism                      │    │
│  │  • harvest() → Claim & distribute yield              │    │
│  │  • Performance fee: 1% (configurable)               │    │
│  │  • Total yield earned: tracked on-chain             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘

🚀 Quick Start

Prerequisites

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

Installation

# Clone the repository
git clone https://github.com/Virgillu/ForgeVault.git
cd ForgeVault

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test

# Generate coverage report
forge coverage

📊 Test Results
$ forge test
Ran 40 tests for 3 suites: 40 passed, 0 failed

Test Suite	Tests	Status
ForgeVaultCore.t.sol	18	✅ Passing
ForgeVaultYield.t.sol	11	✅ Passing
ForgeVaultIntegration.t.sol	11	✅ Passing

🔒 Security Audit

A comprehensive security audit report is available here.

Audit Summary:

✅ 0 Critical issues
✅ 0 High-risk issues
⚠️ 1 Medium, 3 Low, 2 Informational findings
✅ 100% test coverage

📁 Project Structure
ForgeVault/
├── src/
│   ├── ForgeVault.sol          # Core vault contract
│   └── MyToken.sol             # Test ERC-20 token
├── test/
│   ├── unit/
│   │   ├── ForgeVaultCore.t.sol
│   │   └── ForgeVaultYield.t.sol
│   └── integration/
│       └── ForgeVaultIntegration.t.sol
├── docs/
│   └── AUDIT_REPORT.md          # Security audit
├── script/
│   └── DeployForgeVault.s.sol  # Deployment script
├── .github/workflows/
│   └── test.yml                 # CI/CD pipeline
├── foundry.toml
└── README.md

📄 License  MIT License

📫 Contact

Author: Virgillu
Email: virgilsnape@gmail.com
GitHub: @Virgillu

