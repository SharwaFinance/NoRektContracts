# Main Functions

The margin account system of the **Norekt** and **Sharwa** protocols is built around the following core contracts:

- `MarginTrading`
- `MarginAccount`
- `OneClickProxy`
- `MarginAccountManager`
- `LendingMarginAccountManager`
- `LiquidityPool`
- `ModularSwapRouter`
- `HegicModule`
- `UniswapModuleBase`
- `UniswapModuleWithChainlink`
- `UniswapModuleWithChainlinkInvertedFeed`
- `UniswapModuleWithoutChainlink`

## Contents

1. [Health Zones](#1-health-zones)
2. [Core Functions](#2-core-functions)
3. [Zone-Bypassing Functions](#3-zone-bypassing-functions)
4. [Allowed Hegic Options (Strategies)](#4-allowed-hegic-options-strategies)

## 1. Health Zones

Every margin account is always in exactly one of three zones, based on its health. The zone determines which actions are allowed.

| Zone | Meaning | Allowed actions |
| --- | --- | --- |
| 🟢 **Green** | Healthy | Provide ERC-20/721, borrow, repay, withdraw ERC-20/721, swap ERC-20 |
| 🟠 **Yellow** | At risk — must reduce risk | Provide ERC-20/721, repay, swap ERC-20. **No borrowing, no withdrawals** |
| 🔴 **Red** | Insolvent | Must be liquidated |

> **`NO_YELLOW_ROLE`** is a role that bypasses the Yellow Zone check. Calls made with this role are allowed even when the account is in the Yellow Zone (see [Zone-Bypassing Functions](#3-zone-bypassing-functions)).

## 2. Core Functions

Base functions defined across three contracts, each with a distinct responsibility:

- `MarginAccount` — manages balances: ERC-20 collateral, ERC-721 collateral
- `MarginTrading` — Red Zone checks.
- `OneClickProxy` — Yellow Zone checks.

All of the `OneClick` contracts rely on them.

The **Zone checked** column shows which zone boundary the call is validated against. **ERC-721 counted** shows whether the value of ERC-721 (Hegic option) positions is included when that check is evaluated.

| # | Function | Zone checked | ERC-721 counted | Description |
| --- | --- | --- | --- | --- |
| 1 | `provideERC20` | — none — | n/a | Deposits an ERC-20 token into the margin account. |
| 2 | `provideERC721` | — none — | n/a | Deposits an ERC-721 token from Hegic Options. Any system-allowed ERC-721 is accepted. Inverse strategies are not supported. |
| 3 | `borrow` | 🟠 Yellow | ❌ No | Borrows funds from the liquidity pools. Only ERC-20 tokens count as collateral. |
| 4 | `withdrawERC20` | 🟠 Yellow | ❌ No | Withdraws ERC-20 tokens. ERC-721 value is excluded, so users can withdraw ERC-20 while their ERC-721 positions still back the account. |
| 5 | `withdrawERC721` | 🟠 Yellow | ❌ No | Withdraws options from the account. ERC-721 value is excluded from the check. |
| 6 | `repay` | — none — | n/a | Repays the debt. |
| 7 | `exercise` | 🔴 Red | ✅ Yes | Exercises options. |
| 8 | `liquidate` | 🔴 Red | ✅ Yes | Liquidates a margin account. |

## 3. Zone-Bypassing Functions

These functions skip the Yellow Zone check and can only be called with the `NO_YELLOW_ROLE` role.

| Function | Purpose |
| --- | --- |
| `OneClickProxy.borrowNoYellow` | Borrows funds while bypassing the Yellow Zone. JBTD: when a user wants to close a short position (borrowed ETH and sold it for USDC) but doesn't have enough USDC in the account to cover the negative PnL, we allow borrowing USDC to buy back the borrowed ETH and repay the debt. The goal of this operation is to move the debt from a volatile asset (ETH, WBTC) to a stablecoin. |
| `OneClickProxy.withdrawERC20NoYellow` | Required for `swapOutput` in `OneClickEphemeralSwapOutput`. |
| `OneClickProxy.withdrawERC721NoYellow` | Not used as of right now. Implemented to mirror the behaviour of `withdrawERC20NoYellow`, but for ERC-721 tokens. |
| `OneClickNoRekt.multiExerciseRepayWithdraw` | Exercises multiple options (ERC-721), swaps USDC.e for USDC, repays the debt, and withdraws any remaining funds from the account. |


## 4. Allowed Hegic Options (Strategies)

Only explicitly allow-listed Hegic option strategies can be deposited into a margin account (via `provideERC721`). Availability is controlled on the `ModularSwapRouter` contract through the `setAvailebleStrategy` function:

```solidity
setAvailebleStrategy(address strategy, bool isAvailable)
```

- `strategy` — the address of the option strategy.
- `isAvailable` — `true` to enable it for deposit, `false` to disable it.

A strategy's deposit eligibility follows from its state:

| Strategy state | Depositable? |
| --- | --- |
| Not added | ❌ No |
| Added but disabled (`isAvailable = false`) | ❌ No |
| Added and enabled (`isAvailable = true`) | ✅ Yes |
