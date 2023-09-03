// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IQuoterV2.sol";
import "./libraries/LiquidityAmounts.sol";
import "./libraries/TickMath.sol";
import "./interfaces/pool/IRamsesV2Pool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title SwapCalculator
/// @author libevm.eth, ramses
/// @notice Based on Univ3SingleSidedLiquidity by libevm.eth
/// @dev Should be called off-chain, very gas intensive

contract SwapCalculator {
    using TickMath for int24;
    IQuoterV2 internal constant quoter =
        IQuoterV2(0xAA20EFF7ad2F523590dE6c04918DaAE0904E3b20);

    uint256 internal constant BINARY_SEARCH_MAX_ITERATIONS = 128;
    uint256 internal constant MIN_DELTA = 100;

    /// @notice Given a uniswap v3 pool, the liquidity range to provide, and amountIn
    ///         while specifying if its token0 or token1. Find the optimal number of
    ///         tokens to swap from token0/token -> token1/token0 to LP the univ3 pool
    ///         liquidity range with minimal leftovers.
    /// @param pool - UniswapV3 pool address
    /// @param lowerTick - Liquidity lower range
    /// @param upperTick - Liquidity upper range
    /// @param amountIn - Amount of tokens to swap
    /// @param zeroForOne - token0 < token1
    function calcSwap(
        address pool,
        int24 lowerTick,
        int24 upperTick,
        uint256 amountIn,
        bool zeroForOne
    ) external returns (uint256 amountToSwap) {
        // Getting pool info
        uint24 fee = IRamsesV2Pool(pool).fee();
        int24 tickSpacing = IRamsesV2Pool(pool).tickSpacing();

        require(
            lowerTick % tickSpacing == 0 && upperTick % tickSpacing == 0,
            "spacing"
        );

        uint160 lowerSqrtRatioX96 = lowerTick.getSqrtRatioAtTick();
        uint160 upperSqrtRatioX96 = upperTick.getSqrtRatioAtTick();

        (address tokenIn, address tokenOut) = zeroForOne
            ? (IRamsesV2Pool(pool).token0(), IRamsesV2Pool(pool).token1())
            : (IRamsesV2Pool(pool).token1(), IRamsesV2Pool(pool).token0());

        uint256 low;
        uint256 high = amountIn;
        amountToSwap = amountIn / 2;
        uint256 amountOut;

        uint256 leftoverAmount0;
        uint256 leftoverAmount1;
        uint256 prevAmountToSwap;
        uint160 sqrtRatioX96;
        uint256 i;

        uint256 lpAmount0;
        uint256 lpAmount1;
        uint256 amountInPostSwap;

        while (i < BINARY_SEARCH_MAX_ITERATIONS) {
            (amountOut, sqrtRatioX96, , ) = quoter.quoteExactInputSingle(
                IQuoterV2.QuoteExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountToSwap,
                    fee: fee,
                    sqrtPriceLimitX96: 0
                })
            );

            unchecked {
                amountInPostSwap = amountIn - amountToSwap;
            }

            (lpAmount0, lpAmount1) = calcAmounts(
                sqrtRatioX96,
                lowerSqrtRatioX96,
                upperSqrtRatioX96,
                amountInPostSwap,
                amountOut,
                zeroForOne
            );

            if (zeroForOne) {
                unchecked {
                    leftoverAmount0 = amountInPostSwap - lpAmount0;
                    leftoverAmount1 = amountOut - lpAmount1;
                }

                if (leftoverAmount0 > leftoverAmount1) {
                    low = amountToSwap;
                } else {
                    high = amountToSwap;
                }
            } else {
                unchecked {
                    leftoverAmount0 = amountOut - lpAmount0;
                    leftoverAmount1 = amountInPostSwap - lpAmount1;
                }

                if (leftoverAmount0 > leftoverAmount1) {
                    high = amountToSwap;
                } else {
                    low = amountToSwap;
                }
            }

            prevAmountToSwap = amountToSwap;
            unchecked {
                amountToSwap = (low + high) / 2;
            }

            if (amountToSwap > prevAmountToSwap) {
                if (amountToSwap - prevAmountToSwap < MIN_DELTA) {
                    break;
                }
            } else if (amountToSwap < prevAmountToSwap) {
                if (prevAmountToSwap - amountToSwap < MIN_DELTA) {
                    break;
                }
            }

            ++i;
        }
        return (amountToSwap);
    }

    function calcAmounts(
        uint160 sqrtRatioX96,
        uint160 lowerSqrtRatioX96,
        uint160 upperSqrtRatioX96,
        uint256 amountInPostSwap,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint256 lpAmount0, uint256 lpAmount1) {
        uint128 liquidity;
        if (zeroForOne) {
            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                lowerSqrtRatioX96,
                upperSqrtRatioX96,
                amountInPostSwap,
                amountOut
            );
        } else {
            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                lowerSqrtRatioX96,
                upperSqrtRatioX96,
                amountOut,
                amountInPostSwap
            );
        }

        (lpAmount0, lpAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            lowerSqrtRatioX96,
            upperSqrtRatioX96,
            liquidity
        );
    }

    /// @notice estimates the amount to swap assuming sqrtPriceX96 will not change
    /// @notice does not take into account any trading fee
    // perhaps the result from this one can be used as the starting midpoint for the binary search?
    function calcSwapNoRatio(
        address pool,
        int24 lowerTick,
        int24 upperTick,
        uint256 amountIn,
        bool zeroForOne
    ) external view returns (uint256 swapAmount) {
        int24 tickSpacing = IRamsesV2Pool(pool).tickSpacing();

        require(
            lowerTick % tickSpacing == 0 && upperTick % tickSpacing == 0,
            "spacing"
        );

        address token0 = IRamsesV2Pool(pool).token0();
        address token1 = IRamsesV2Pool(pool).token1();

        (uint160 sqrtRatioX96, , , , , , ) = IRamsesV2Pool(pool).slot0();
        uint160 lowerSqrtRatioX96 = lowerTick.getSqrtRatioAtTick();
        uint160 upperSqrtRatioX96 = upperTick.getSqrtRatioAtTick();

        uint256 amountOut;
        uint128 liquidity;
        uint256 decimals;
        if (zeroForOne) {
            decimals = 10 ** IERC20Metadata(token0).decimals();
            liquidity = LiquidityAmounts.getLiquidityForAmount0(
                sqrtRatioX96,
                upperSqrtRatioX96,
                decimals
            );
            (, amountOut) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                lowerSqrtRatioX96,
                upperSqrtRatioX96,
                liquidity
            );
        } else {
            decimals = 10 ** IERC20Metadata(token1).decimals();
            liquidity = LiquidityAmounts.getLiquidityForAmount1(
                lowerSqrtRatioX96,
                sqrtRatioX96,
                decimals
            );
            (amountOut, ) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                lowerSqrtRatioX96,
                upperSqrtRatioX96,
                liquidity
            );
        }

        uint256 price = Math.mulDiv(
            (sqrtRatioX96 * 10 ** 18),
            sqrtRatioX96,
            2 ** 192
        );

        amountOut = zeroForOne
            ? (amountOut * 10 ** 18) / price
            : (amountOut * price) / 10 ** 18;

        swapAmount = amountIn - (amountIn * decimals) / (decimals + amountOut);
    }
}
