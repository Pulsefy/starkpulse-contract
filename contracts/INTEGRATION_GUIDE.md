# StarkPulse Contracts Integration Guide

This guide provides step-by-step instructions for integrating StarkPulse smart contracts with your own systems or dApps.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Contract Deployment](#contract-deployment)
- [Interacting with Contracts](#interacting-with-contracts)
- [Example Usage](#example-usage)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

---

## Overview

StarkPulse provides a suite of Cairo smart contracts for analytics, portfolio tracking, token vesting, and more. This guide will help you integrate these contracts into your own projects.

## Prerequisites

- Familiarity with Cairo and StarkNet development
- Access to a StarkNet-compatible wallet
- Node.js and Scarb installed

## Contract Deployment

To deploy StarkPulse contracts, follow these steps:

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/Pulsefy/starkpulse-contract.git
   cd starkpulse-contract/contracts
   ```

2. **Install Dependencies:**
   Ensure you have [Scarb](https://docs.swmansion.com/scarb/) and [Cairo](https://book.cairo-lang.org/) installed.

   ```bash
   scarb build
   ```

3. **Configure Deployment:**

   - Update constructor parameters in each contract as needed (e.g., admin addresses, token addresses, initial supply).
   - Review and edit the deployment scripts or use your preferred StarkNet deployment tool.

4. **Deploy Contracts:**
   Example using [starknet-CLI](https://docs.starknet.io/documentation/tools/cli/):

   ```bash
   starknet declare --contract src/tokens/erc20_token.cairo
   starknet deploy --class_hash <ERC20_CLASS_HASH> --inputs <constructor_args>
   # Repeat for other contracts (TokenVesting, PortfolioTracker, etc.)
   ```

5. **Record Deployed Addresses:**
   Save the contract addresses for use in integration and configuration.

---

## Interacting with Contracts

You can interact with StarkPulse contracts using Cairo, Python (starknet.py), or JavaScript (starknet.js). Below are examples using Python:

### Example: Transfer ERC20 Tokens

```python
from starknet_py.contract import Contract

erc20 = await Contract.from_address(<ERC20_ADDRESS>, client)
await erc20.functions["transfer"].invoke(<RECIPIENT_ADDRESS>, 100)
```

### Example: Create a Vesting Schedule

```python
vesting = await Contract.from_address(<VESTING_ADDRESS>, client)
await vesting.functions["create_vesting_schedule"].invoke(
    <BENEFICIARY>, 1000, <START_TIME>, <DURATION>, <CLIFF>
)
```

### Example: Track Portfolio Asset

```python
portfolio = await Contract.from_address(<PORTFOLIO_ADDRESS>, client)
await portfolio.functions["add_asset"].invoke(<ASSET_ADDRESS>, 500)
```

---

## Example Usage

- **Minting Tokens (as minter):**
  ```python
  await erc20.functions["mint"].invoke(<TO_ADDRESS>, 1000)
  ```
- **Releasing Vested Tokens:**
  ```python
  await vesting.functions["release_tokens"].invoke(<SCHEDULE_ID>)
  ```
- **Querying Analytics:**
  ```python
  await analytics.functions["get_user_action_count"].call(<USER>, <ACTION_ID>)
  ```

---

## Security Considerations

- **Access Control:** Only authorized addresses (admin, minter, etc.) can perform sensitive actions (mint, pause, revoke vesting, etc.).
- **Pausing:** Pausing disables transfers, vesting, and other critical operations. Use in emergencies.
- **Input Validation:** All contracts validate addresses and amounts to prevent misuse.
- **Revocation:** Revoked vesting schedules cannot be released further.
- **Whitelisting:** Restrict analytics and sensitive functions to trusted contracts in production.
- **Upgradeability:** Review upgrade paths and migration plans before deploying to mainnet.

---

## Troubleshooting

- **Deployment Fails:**
  - Check constructor arguments and ensure all dependencies are deployed.
  - Ensure you have enough funds for deployment fees.
- **Transaction Reverts:**
  - Review error messages for permission or input validation issues.
  - Ensure the contract is not paused.
- **Integration Issues:**
  - Double-check contract addresses and ABI compatibility.
  - Use the latest version of StarkNet tooling.
- **Analytics Not Updating:**
  - Ensure only whitelisted contracts are calling analytics functions in production.

For further help, consult the contract-level documentation and the [README](https://github.com/Pulsefy/starkpulse-contract?tab=readme-ov-file).
