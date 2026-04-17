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
