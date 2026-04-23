// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceOracle {
    /// @notice Returns the latest stored price data for an asset.
    /// @param asset The asset address.
    /// @return price The asset price with 8 decimals.
    /// @return updatedAt The timestamp of the latest update.
    function getPrice(address asset) external view returns (uint256 price, uint256 updatedAt);

    /// @notice Returns the oracle price precision.
    /// @return oracleDecimals The number of oracle decimals.
    function decimals() external view returns (uint8 oracleDecimals);
}
