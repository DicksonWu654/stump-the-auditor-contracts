// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "./IPriceOracle.sol";

interface ILendingPool {
    struct InterestRateParams {
        uint128 baseRateRayPerYear;
        uint128 slope1RayPerYear;
        uint128 slope2RayPerYear;
        uint64 optimalUtilizationBps;
    }

    struct Reserve {
        bool listed;
        bool borrowEnabled;
        bool useAsCollateral;
        uint8 decimals;
        uint16 collateralFactorBps;
        uint16 liquidationThresholdBps;
        uint16 liquidationBonusBps;
        uint16 reserveFactorBps;
        uint128 totalScaledSupply;
        uint128 totalScaledBorrow;
        uint256 supplyIndex;
        uint256 borrowIndex;
        uint64 lastUpdateTimestamp;
        uint256 accruedReserves;
        InterestRateParams irParams;
    }

    event ReserveListed(
        address indexed asset,
        uint8 decimals,
        uint16 collateralFactorBps,
        uint16 liquidationThresholdBps,
        uint16 liquidationBonusBps,
        uint16 reserveFactorBps
    );
    event ReserveParamsUpdated(
        address indexed asset,
        uint16 collateralFactorBps,
        uint16 liquidationThresholdBps,
        uint16 liquidationBonusBps,
        uint16 reserveFactorBps
    );
    event InterestRateParamsUpdated(
        address indexed asset, uint128 baseRate, uint128 slope1, uint128 slope2, uint64 optimalUtilBps
    );
    event BorrowEnabled(address indexed asset, bool enabled);
    event CollateralEnabled(address indexed asset, bool enabled);
    event Supplied(address indexed user, address indexed asset, uint256 amount, uint256 scaledAmount);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount, uint256 scaledAmount);
    event Borrowed(address indexed user, address indexed asset, uint256 amount, uint256 scaledAmount);
    event Repaid(
        address indexed user, address indexed asset, uint256 amount, uint256 scaledAmount, address indexed payer
    );
    event Liquidated(
        address indexed borrower,
        address indexed liquidator,
        address indexed collateralAsset,
        address debtAsset,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 liquidatorBonus
    );
    event IndexUpdated(address indexed asset, uint256 supplyIndex, uint256 borrowIndex, uint256 reserveAccruedDelta);
    event OracleUpdated(address indexed oracle);
    event CloseFactorUpdated(uint256 bps);
    event ReservesWithdrawn(address indexed asset, uint256 amount, address indexed to);

    error ReserveNotListed(address asset);
    error ReserveAlreadyListed(address asset);
    error BorrowDisabled(address asset);
    error CollateralDisabled(address asset);
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientSupply(address asset, uint256 requested, uint256 available);
    error InsufficientLiquidity(address asset, uint256 requested, uint256 available);
    error HealthFactorBelowThreshold(uint256 hf);
    error HealthFactorNotBelowThreshold(uint256 hf);
    error NoDebt(address user, address asset);
    error PriceStale(address asset, uint256 updatedAt, uint256 now_);
    error PriceZero(address asset);
    error CollateralFactorTooHigh(uint256 requested, uint256 max);
    error LiquidationThresholdInvalid(uint256 ltv, uint256 liq);
    error LiquidationBonusTooHigh(uint256 requested, uint256 max);
    error ReserveFactorTooHigh(uint256 requested, uint256 max);
    error CloseFactorTooHigh(uint256 requested, uint256 max);
    error SelfLiquidation();
    error DebtAssetIsCollateralAsset(); // liquidation: collateralAsset != debtAsset required (simplifies math; document as an intentional limit)
    error LiquidationAmountExceedsCloseFactor(uint256 requested, uint256 max);
    error UnsupportedToken(address token); // fee-on-transfer
    error ReserveStillInUse(address asset);

    /// @notice Supplies an asset to the pool for `onBehalfOf`.
    /// @param asset The reserve asset being supplied.
    /// @param amount The raw token amount to supply.
    /// @param onBehalfOf The account credited with the resulting scaled supply balance.
    function supply(address asset, uint256 amount, address onBehalfOf) external;

    /// @notice Withdraws up to `amount` of supplied liquidity to `to`.
    /// @param asset The reserve asset being withdrawn.
    /// @param amount The raw token amount to withdraw, or `type(uint256).max` for full balance.
    /// @param to The recipient of the withdrawn tokens.
    /// @return withdrawn The actual token amount withdrawn.
    function withdraw(address asset, uint256 amount, address to) external returns (uint256 withdrawn);

    /// @notice Borrows an asset against the caller's collateral.
    /// @param asset The reserve asset to borrow.
    /// @param amount The raw token amount to borrow.
    /// @param to The recipient of the borrowed tokens.
    function borrow(address asset, uint256 amount, address to) external;

    /// @notice Repays debt for `onBehalfOf`.
    /// @param asset The reserve asset being repaid.
    /// @param amount The raw token amount to repay, or `type(uint256).max` for full debt.
    /// @param onBehalfOf The borrower whose debt is reduced.
    /// @return repaid The actual token amount repaid.
    function repay(address asset, uint256 amount, address onBehalfOf) external returns (uint256 repaid);

    /// @notice Liquidates an unhealthy borrow position by repaying debt and seizing collateral.
    /// @param borrower The unhealthy borrower.
    /// @param collateralAsset The collateral reserve to seize.
    /// @param debtAsset The debt reserve to repay.
    /// @param debtToCover The requested debt amount to cover, subject to the close factor.
    /// @return debtRepaid The actual debt amount repaid.
    /// @return collateralSeized The actual collateral amount seized as an internal supply position.
    function liquidate(address borrower, address collateralAsset, address debtAsset, uint256 debtToCover)
        external
        returns (uint256 debtRepaid, uint256 collateralSeized);

    /// @notice Publicly accrues interest for a reserve without mutating balances otherwise.
    /// @param asset The reserve asset to accrue.
    function accrueInterest(address asset) external;

    /// @notice Returns aggregate collateral, debt, borrowing power, and health for a user.
    /// @param user The user account.
    /// @return totalCollateralValueWad The total eligible collateral value in WAD.
    /// @return totalDebtValueWad The total debt value in WAD.
    /// @return availableBorrowsWad The remaining borrowing capacity in WAD using collateral factors.
    /// @return healthFactor The health factor in WAD, or `type(uint256).max` when debt is zero.
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralValueWad,
            uint256 totalDebtValueWad,
            uint256 availableBorrowsWad,
            uint256 healthFactor
        );

    /// @notice Returns the current supplied and borrowed balances for a user in one reserve.
    /// @param user The user account.
    /// @param asset The reserve asset.
    /// @return supplyBalance The supplied balance in raw token units.
    /// @return borrowBalance The borrowed balance in raw token units.
    function getUserReserveData(address user, address asset)
        external
        view
        returns (uint256 supplyBalance, uint256 borrowBalance);

    /// @notice Returns simulated reserve data including accrued indices up to the current timestamp.
    /// @param asset The reserve asset.
    /// @return reserve The reserve snapshot.
    function getReserveData(address asset) external view returns (Reserve memory reserve);

    /// @notice Returns the list of listed reserve assets.
    /// @return assets The reserve list.
    function getReserveList() external view returns (address[] memory assets);

    /// @notice Returns the user's tracked collateral-asset list.
    /// @param user The user account.
    /// @return assets The user's collateral asset list.
    function getUserCollateralAssets(address user) external view returns (address[] memory assets);

    /// @notice Returns the user's tracked borrow-asset list.
    /// @param user The user account.
    /// @return assets The user's borrow asset list.
    function getUserBorrowAssets(address user) external view returns (address[] memory assets);

    /// @notice Returns the current reserve utilization in RAY.
    /// @param asset The reserve asset.
    /// @return utilizationRay The utilization ratio in RAY.
    function utilizationRateRay(address asset) external view returns (uint256 utilizationRay);

    /// @notice Returns the current borrow rate per second in RAY.
    /// @param asset The reserve asset.
    /// @return rateRayPerSecond The borrow rate per second in RAY.
    function currentBorrowRateRay(address asset) external view returns (uint256 rateRayPerSecond);

    /// @notice Returns the current supply rate per second in RAY.
    /// @param asset The reserve asset.
    /// @return rateRayPerSecond The supply rate per second in RAY.
    function currentSupplyRateRay(address asset) external view returns (uint256 rateRayPerSecond);

    /// @notice Lists a new reserve.
    /// @param asset The reserve asset to list.
    /// @param irParams The reserve's interest-rate parameters.
    /// @param collateralFactorBps The collateral factor in basis points.
    /// @param liquidationThresholdBps The liquidation threshold in basis points.
    /// @param liquidationBonusBps The liquidation bonus in basis points.
    /// @param reserveFactorBps The reserve factor in basis points.
    /// @param borrowEnabled Whether borrowing this asset is enabled.
    /// @param useAsCollateral Whether supplied balances of this asset count as collateral.
    function listReserve(
        address asset,
        InterestRateParams calldata irParams,
        uint16 collateralFactorBps,
        uint16 liquidationThresholdBps,
        uint16 liquidationBonusBps,
        uint16 reserveFactorBps,
        bool borrowEnabled,
        bool useAsCollateral
    ) external;

    /// @notice Updates reserve collateral and reserve-factor parameters.
    /// @param asset The reserve asset to update.
    /// @param collateralFactorBps The new collateral factor in basis points.
    /// @param liquidationThresholdBps The new liquidation threshold in basis points.
    /// @param liquidationBonusBps The new liquidation bonus in basis points.
    /// @param reserveFactorBps The new reserve factor in basis points.
    function setReserveParams(
        address asset,
        uint16 collateralFactorBps,
        uint16 liquidationThresholdBps,
        uint16 liquidationBonusBps,
        uint16 reserveFactorBps
    ) external;

    /// @notice Updates reserve interest-rate parameters.
    /// @param asset The reserve asset to update.
    /// @param irParams The new interest-rate parameters.
    function setInterestRateParams(address asset, InterestRateParams calldata irParams) external;

    /// @notice Enables or disables borrowing for a reserve.
    /// @param asset The reserve asset to update.
    /// @param enabled Whether borrowing should be enabled.
    function setBorrowEnabled(address asset, bool enabled) external;

    /// @notice Enables or disables use of a reserve as collateral.
    /// @param asset The reserve asset to update.
    /// @param enabled Whether collateral usage should be enabled.
    function setCollateralEnabled(address asset, bool enabled) external;

    /// @notice Updates the oracle used for USD pricing.
    /// @param newOracle The new oracle contract.
    function setOracle(IPriceOracle newOracle) external;

    /// @notice Updates the global close factor.
    /// @param bps The new close factor in basis points.
    function setCloseFactor(uint256 bps) external;

    /// @notice Withdraws protocol reserves of an asset.
    /// @param asset The reserve asset whose reserves are being withdrawn.
    /// @param amount The raw token amount to withdraw from accrued reserves.
    /// @param to The recipient of the withdrawn reserves.
    function withdrawReserves(address asset, uint256 amount, address to) external;

    /// @notice Pauses supply, borrow, and liquidation actions.
    function pause() external;

    /// @notice Unpauses supply, borrow, and liquidation actions.
    function unpause() external;
}
