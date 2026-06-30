# NoRekt

**Hedged lending for borrowers who don’t want to get liquidated.**

NoRekt brings option-based downside protection directly into the DeFi lending flow. Instead of forcing borrowers to manage collateral, debt, and hedges across separate protocols, NoRekt treats them as one combined position.

Deposit ETH. Borrow USDC. Add protection. Stay NoRekt.

---

## What NoRekt Does

NoRekt lets  users create hedged lending positions by combining:

- **ETH collateral**
- **USDC debt**
- **Option-based downside protection**
- **Net account value and net LTV tracking**

The result is a borrower-facing product where protection is part of the lending experience from the start.

---

## How Hedged Lending Works

In a standard lending position, falling collateral value increases loan-to-value ratio, pushing the borrower toward liquidation.

In a NoRekt position, the loan and hedge are evaluated together. A borrower can buy put-option protection on ETH so that when ETH falls, the option can gain value while the collateral loses value.

Simplified flow:

```text
ETH price falls
      ↓
ETH collateral value decreases
      ↓
Put option value may increase
      ↓
Hedge value can offset collateral loss
      ↓
Net LTV may remain healthier than an unprotected loan
```

NoRekt uses **American-style options**, which can be exercised before expiry. This matters because protection can become useful during a market move, not only at maturity.

For a put option, intrinsic value is:

```text
max(strike price - ETH price, 0)
```

---

## Example

Assume:

| Parameter | Value |
| --- | ---: |
| ETH price | $3,300 |
| Collateral | 10 ETH |
| Collateral value | $33,000 |
| USDC borrowed | $26,400 |
| Starting LTV | 80% |
| Liquidation LTV | 83% |

### Without protection

At 83% liquidation LTV, the position reaches liquidation when collateral value falls to approximately:

```text
$26,400 / 0.83 = $31,807
```

That means ETH only needs to fall to about:

```text
$31,807 / 10 = $3,181
```

A move from $3,300 to $3,181 is only about **3.6%**.

### With put protection

Now assume the borrower buys an at-the-money ETH put with a **$3,300 strike**.

If ETH falls 30% to $2,310:

| Component | Value |
| --- | ---: |
| ETH collateral value | $23,100 |
| Put intrinsic value | $9,900 |
| Combined collateral + hedge value | $33,000 |
| Debt | $26,400 |
| Simplified net LTV | 80% |

Excluding premium, interest, fees, slippage, and execution constraints, the put’s intrinsic value can offset the collateral loss and help keep the account near its starting LTV.

That is the core of NoRekt:

> The hedge is not outside the loan. The hedge is part of the loan.

---

## Architecture

NoRekt is built on a hedged lending stack:

```text
┌──────────────────────────────┐
│          NoRekt UI            │
│ Borrower-facing hedged loan   │
└───────────────┬──────────────┘
                │
┌───────────────▼──────────────┐
│   Sharwa Margin Account       │
│ Tracks collateral, debt,      │
│ hedge positions, and net LTV  │
└───────────────┬──────────────┘
                │
┌───────────────▼──────────────┐
│        Hegic Options          │
│ American-style option         │
│ protection                    │
└──────────────────────────────┘
```

### Sharwa

Sharwa provides the margin-account primitive that allows collateral, debt, and hedge positions to be tracked together inside one account.

### Hegic

Hegic provides American-style options that can be used as downside protection for ETH-backed borrowing.

### NoRekt

NoRekt turns this infrastructure into a borrower-facing product where users can borrow USDC against ETH and attach option protection to the loan.

---

## Core Concepts

### Collateral

The asset deposited by the borrower. NoRekt currently focuses on ETH-backed borrowing.

### Debt

The stablecoin borrowed against the collateral. NoRekt examples use USDC.

### Protection

An option position, typically a put option, that may gain value when the collateral asset falls.

### Net Account Value

The combined value of collateral and hedge positions, minus debt and relevant costs.

### Net LTV

A more complete view of loan risk that accounts for hedge value alongside collateral value.

---


## Important Risk Notes

NoRekt reduces liquidation risk; it does not eliminate risk.

A position may still be liquidated if:

- The borrower does not buy protection.
- The borrower buys only partial protection.
- The protected range is exhausted.
- Protection expires and is not renewed.
- Premiums, interest, fees, slippage, or execution costs reduce account value.
- Market conditions move faster than the position can be adjusted.
- Smart contract, oracle, liquidity, or integration risks occur.

Protection is not magic. Risk does not disappear. It becomes priced and easier to manage.

---

## Product Flow

```text
1. Deposit ETH
2. Borrow USDC
3. Open the Dashboard
4. Click Buy Protection
5. Add option-based downside protection
6. Monitor net LTV and protection expiry
```

Borrowing without protection may still result in liquidation. After borrowing, users should open their position on the Dashboard and add protection if they want a hedged loan.

---


## Disclaimer

NoRekt is not financial advice. Hedged lending involves smart contract risk, liquidation risk, oracle risk, liquidity risk, market risk, and options risk. Option protection can reduce downside exposure but may expire, lose value, or fail to fully offset losses.

Users are responsible for understanding their positions before borrowing, buying protection, or interacting with any DeFi protocol.
