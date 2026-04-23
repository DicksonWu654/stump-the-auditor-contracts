# Stump the Auditor — Base Contracts

Three production-style DeFi contracts used in CertiK's **Stump the Auditor** challenge. Participants modify one in ≤50 lines to plant a real fund-draining vulnerability, run it through AI Auditor Lite, and submit if it goes undetected. Top stumps win AI Auditor credits.

Contracts here are the **unmodified base** — written to be secure, verified across multiple rounds of adversarial review. Your job is to break them.

→ Challenge details and submission form: [challenge page / announcement link]
→ Rules: [link]

---

## The Three Contracts

### `src/Vault.sol` — Multi-Asset Vault

An ERC-4626-inspired vault that accepts multiple whitelisted stable-denominated ERC-20s, issues shares proportional to deposits, and includes:

- Multi-asset support with WAD normalization across decimals (6, 8, 18)
- Management fee (time-based, annualized) and performance fee (on yield above a per-share high-water mark)
- Block-based withdrawal timelock with per-asset liquidity reservation
- Two-step withdraw (`requestWithdraw` → wait → `claimWithdraw`) plus cancellation
- Pull-based `reportYield(asset, amount)` — admin deposits real tokens as yield
- Virtual-share offset for first-depositor inflation protection
- Fee-on-transfer rejection via pre/post balance delta

~553 lines. ERC-4626-like share math, per-share HWM, multi-asset decimals.

### `src/Staking.sol` — Lock-Tiered Staking

A Synthetix StakingRewards-style contract with lock tiers, multi-reward distribution, and penalty redistribution:

- Configurable lock tiers (e.g., 30/60/90 days) with boost multipliers (e.g., 1x / 1.5x / 3x)
- Multiple reward tokens, each with independent `rewardRate` / `periodFinish` / `rewardPerTokenStored`
- Early-unstake penalty routed into a penalty pool that drips back into the primary reward stream
- Per-user active stake count/boosted-amount tracked in storage (not scanned from history)
- `compound()` to restake primary-token rewards
- Penalty flush folds into remaining stream duration (no schedule reset)

~630 lines. Synthetix accumulator pattern, multi-reward, boosts, penalty redistribution.

### `src/Lending.sol` + `src/libs/LendingMath.sol` — Lending Pool

An Aave v2-lite lending protocol:

- Scaled-balance supply and borrow with RAY-precision indices
- Kinked interest rate model (base + slope1 + slope2 at optimal utilization)
- Price oracle with staleness check (see `src/PriceOracle.sol`)
- Multi-asset collateral with per-reserve collateral factor, liquidation threshold, liquidation bonus, reserve factor
- Health-factor-based liquidation with close factor
- Liquidator receives collateral as an internal supply position (Aave v2 `receiveAToken=true` style)
- Per-reserve `accruedReserves` protected from supplier/borrower withdrawal

~760 lines + ~165 lines of math library. Kinked IR curve, oracle staleness, liquidation mechanics.

### Supporting Files

- `src/PriceOracle.sol` — settable oracle with Chainlink-style 8-decimal prices (used by Lending)
- `src/interfaces/` — interface stubs for each contract
- `src/mocks/MockERC20.sol` — for tests

## Requirements

- [Foundry](https://book.getfoundry.sh/)
- Solidity `^0.8.24`, EVM version `cancun`
- OpenZeppelin Contracts v5.1

## Quickstart

```bash
git clone --recurse-submodules https://github.com/DicksonWu654/stump-the-auditor-contracts
cd stump-the-auditor-contracts

forge build
forge test
```

Invariant tests:

```bash
forge test --match-path "test/invariants/*"
```

Fuzz coverage:

```bash
forge test --fuzz-runs 1000
```

## For Challenge Participants

1. Read the contract you plan to attack. Don't skim.
2. Identify where two features interact — fee accrual × timelock, reward accumulator × boost, interest accrual × liquidation threshold. These are usually where the best bugs live.
3. Plant the smallest possible change. Single-line rounding flips beat elaborate reworks.
4. Scan via AI Auditor Lite. If caught, pivot.
5. Submit via the official form when AI Auditor misses the bug.

Full rules, severity bar, prize structure, and submission format: [challenge page].

## Severity Bar

Submissions must be **Critical** or **High** severity. Specifically:

**Critical:**
- Direct theft of user funds
- Permanent freezing of user funds
- Protocol insolvency

**High:**
- Theft of unclaimed yield or rewards
- Permanent freezing of unclaimed yield
- Temporary freezing of user funds

Medium and below are not accepted. Neither are trivial backdoors (public `drain()`, hardcoded addresses, removed modifiers).

## Verification

These base contracts have passed:

- Self-audit by the original writer
- Two independent adversarial reviews per contract (different LLM families, fresh sessions)
- Multiple rounds of fixing based on review findings
- Foundry unit tests (>90% line coverage per contract)
- Foundry invariant tests (100+ runs × 50 depth)
- Foundry fuzz tests (1000+ runs)

If you find a bug in the base contracts themselves (not something you planted), please email [contact] — we'll patch, announce publicly, and reset affected scan counts. Real base-contract bugs shouldn't happen, but if they do we want to know.

## License

MIT.
