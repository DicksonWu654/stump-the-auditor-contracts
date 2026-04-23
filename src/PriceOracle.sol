// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract PriceOracle is IPriceOracle, Ownable2Step {
    error ZeroAddress();

    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);

    mapping(address => uint256) private priceOf;
    mapping(address => uint256) private updatedAtOf;

    constructor() Ownable(msg.sender) {}

    /// @notice Sets the latest price for an asset.
    /// @param asset The asset address.
    /// @param price The asset price with 8 decimals.
    function setPrice(address asset, uint256 price) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();

        priceOf[asset] = price;
        updatedAtOf[asset] = block.timestamp;

        emit PriceUpdated(asset, price, block.timestamp);
    }

    /// @notice Returns the latest stored price and update time for an asset.
    /// @param asset The asset address.
    /// @return price The asset price with 8 decimals.
    /// @return updatedAt The timestamp of the latest update.
    function getPrice(address asset) external view override returns (uint256 price, uint256 updatedAt) {
        return (priceOf[asset], updatedAtOf[asset]);
    }

    /// @notice Returns the oracle price precision.
    /// @return oracleDecimals The number of oracle decimals.
    function decimals() external pure override returns (uint8 oracleDecimals) {
        return 8;
    }
}
