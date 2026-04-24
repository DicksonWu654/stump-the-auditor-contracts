# Stump the AI Auditor — Base Contracts

Three production-style DeFi contracts. Modify one (≤50 lines) to plant a fund-draining vulnerability, then try to slip it past CertiK's AI Auditor Lite. If the scan misses it, submit. Top three stumps win.

## Challenge Window

**2026-04-28, 9:00 AM ET → 2026-05-12, 23:59 ET.** Rolling submissions. Deadline is firm.

- Apply: https://docs.google.com/forms/d/1dPBQaHMjTGleUUfIo0CJtqygHTSuFULY_l-pQX6kQ-4
- Submission form: sent in your approval email.
- Results: Wed 2026-05-20.

## Prizes

| Place | Prize |
|---|---|
| 1st | $1,000 AI Auditor credits + interview fast-track |
| 2nd | $500 AI Auditor credits + interview fast-track |
| 3rd | $250 AI Auditor credits + interview fast-track |

Every valid stump gets public recognition (opt-in). Interview fast-track = profile handed directly to CertiK's auditor hiring team with challenge context.

## Rules

- **≤50 lines modified** (added + changed; comments count, whitespace does not)
- **4 AI Auditor Lite scans** per person, flexible across the three contracts
- **Up to 3 submissions** per person, one per contract
- **Must compile** under this repo's Foundry config
- **No new imports**; no removed or renamed external/public functions
- **Severity bar: Critical or High only**
- **No trivial backdoors** — your diff has to read like a real developer mistake

### Severity Bar

**Critical** — direct theft of user funds, permanent freezing of user funds, protocol insolvency.
**High** — theft or permanent freezing of unclaimed yield, temporary freezing of user funds.

Rejected: Medium and below; exploits requiring admin action or external conditions (oracle depegs, MEV on pools outside scope).

### Auto-Disqualified

- Unrestricted `drain()` / `rescue()` / `emergencyWithdraw()`
- Hardcoded attacker address
- Removed `onlyOwner` / `whenNotPaused` / `nonReentrant` with no replacement
- Inverted access control

## Submission Contents

- Modified `.sol`
- Unified diff vs the base
- AI Auditor Lite scan URL (we verify internally; does not need to be publicly shareable)
- 200–500 word writeup: what the bug is, how to exploit, impact, why a dev could realistically ship it
- Severity claim with one-paragraph justification

## Trust Model

The owner (`Ownable2Step`) is assumed honest — admin-only exploits are out of scope. Bugs must be exploitable by an unprivileged attacker, or require only normal admin actions (config changes, reward issuance).

External conditions the attacker doesn't control (unrelated oracle depegs, MEV on out-of-scope pools) are also out of scope.

Contracts use `Ownable2Step`, `ReentrancyGuard`, `Pausable`, and `SafeERC20`. Fee-on-transfer and rebasing tokens are explicitly rejected via pre/post balance deltas.

## The Three Contracts

### `src/Vault/Vault.sol` — Multi-Asset Vault

ERC-4626-inspired vault over multiple whitelisted stablecoins. Shares claim pro-rata on WAD-normalized assets. Management fee (time-based) + performance fee (on per-share HWM lift). Block-based withdrawal timelock with proportional pending-side yield share. Virtual-share offset blocks first-depositor inflation attacks. Full mechanics: [`src/Vault/README.md`](./src/Vault/README.md).

### `src/Staking/Staking.sol` — Lock-Tiered Staking

Synthetix `StakingRewards` × MasterChef × veToken-lite. Users stake into tiered locks with boost multipliers, accrue rewards in multiple tokens, and early-unstake penalties redistribute to remaining stakers. `primaryRewardToken == stakingToken` is a load-bearing invariant. Full mechanics: [`src/Staking/README.md`](./src/Staking/README.md).

### `src/Lending/Lending.sol` — Lending Pool

Aave v2-lite. Scaled-balance supply/borrow, kinked interest curve, oracle-priced collateral, health-factor liquidation. Scales: **RAY** (1e27) for indices and rates, **WAD** (1e18) for USD and HF, **BPS** (10_000) for config params, **1e8** for raw Chainlink-style oracle prices. Full mechanics: [`src/Lending/README.md`](./src/Lending/README.md).

## Where to Look

Good stumps live where **two features interact**:

- **Vault** — fee accrual × pending withdrawals, reportYield × active/pending skew
- **Staking** — reward accumulator × compound/emergency ordering, penalty flush × rate recalc
- **Lending** — interest accrual × liquidation, oracle staleness × health factor, index rounding × long-horizon drift

Single-line rounding flips often beat multi-line reworks. Diff size isn't judged — severity, subtlety, realism, and novelty are.

## Getting Started

```bash
git clone --recurse-submodules https://github.com/CertiKProject/stump-the-auditor-contracts
cd stump-the-auditor-contracts
forge build
forge test
```

Invariant + fuzz coverage:

```bash
forge test --match-path "test/invariants/*"
forge test --fuzz-runs 1000
```

**PoC template:** copy `test/PlantPoC.t.sol.example` → `test/PlantPoC.t.sol`, plant your bug, and prove the exploit with a Foundry test before submitting.

### Scanning Flow

1. Modify one of the three contracts (≤50 lines).
2. `forge build` must still pass.
3. Scan at https://aiauditor.certik.com (Lite mode only — Max is disabled for the challenge).
4. If Lite flags your bug, one scan is consumed; you have 3 left.
5. If Lite misses it, copy the scan URL and submit via the form URL in your approval email.

## Requirements

- [Foundry](https://book.getfoundry.sh/) — install via `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- Solidity `^0.8.24`, EVM version `cancun`
- OpenZeppelin Contracts v5.1 (pinned submodule)

If `forge build` fails on a fresh clone of the unmodified base, that's our bug — email us and we'll patch + reset your scan count on the affected contract.

## Contact

**dickson.wu@certik.com** — rules questions, scan resets, base-contract bug reports.

## License

MIT. See [LICENSE](./LICENSE).
