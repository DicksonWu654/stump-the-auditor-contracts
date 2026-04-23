// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {PriceOracle} from "src/PriceOracle.sol";
import {BaseTest} from "test/helpers/BaseTest.sol";

contract PriceOracleTest is BaseTest {
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);

    PriceOracle internal oracle;

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        oracle = new PriceOracle();
    }

    function testSetPriceIsOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        oracle.setPrice(alice, 1e8);

        vm.prank(owner);
        oracle.setPrice(alice, 1e8);

        (uint256 price,) = oracle.getPrice(alice);
        assertEq(price, 1e8);
    }

    function testSetPriceRejectsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(PriceOracle.ZeroAddress.selector);
        oracle.setPrice(address(0), 1e8);
    }

    function testSetPriceEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit PriceUpdated(alice, 123_456_789, block.timestamp);

        vm.prank(owner);
        oracle.setPrice(alice, 123_456_789);
    }

    function testGetPriceReturnsStoredValuesAtSetTime() public {
        warp(90);

        vm.prank(owner);
        oracle.setPrice(bob, 2_500e8);

        (uint256 price, uint256 updatedAt) = oracle.getPrice(bob);
        assertEq(price, 2_500e8);
        assertEq(updatedAt, block.timestamp);
    }

    function testDecimalsReturnsEight() public view {
        assertEq(oracle.decimals(), 8);
    }
}
