import { ethers } from "hardhat";
import { SingleSidedLiquidityLib, SwapCalculator } from "../typechain-types";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { SingleSidedV2 } from "../typechain-types";

describe("zapCalcs", function () {
  async function deploy() {
    const Zap = await ethers.getContractFactory("SingleSidedLiquidityLib");
    const zap = (await Zap.deploy()) as SingleSidedLiquidityLib;

    const ZapTwo = await ethers.getContractFactory("SwapCalculator");
    const zapTwo = (await ZapTwo.deploy()) as SwapCalculator;

    return { zap, zapTwo };
  }

  it("Should not revert", async function () {
    const { zap, zapTwo } = await loadFixture(deploy);
    console.log(
      await zap.getParamsForSingleSidedAmount.staticCall(
        "0x307fecfc2f14082f9abe641cd09737b77856b640",
        -126200,
        -123000,
        "1000000000000000000",
        true
      )
    );

    console.log(
      await zapTwo.calcSwap.staticCall(
        "0x307fecfc2f14082f9abe641cd09737b77856b640",
        -126200,
        -123000,
        "1000000000000000000",
        true
      )
    );
  });

  it("Should not revert oneForZero", async function () {
    const { zap, zapTwo } = await loadFixture(deploy);
    console.log(
      await zap.getParamsForSingleSidedAmount.staticCall(
        "0x307fecfc2f14082f9abe641cd09737b77856b640",
        -126200,
        -123000,
        "1000000000000000000",
        false
      )
    );

    console.log(
      await zapTwo.calcSwap.staticCall(
        "0x307fecfc2f14082f9abe641cd09737b77856b640",
        -126200,
        -123000,
        "1000000000000000000",
        false
      )
    );

    console.log(
      await zapTwo.calcSwapNoRatio(
        "0x307fecfc2f14082f9abe641cd09737b77856b640",
        -126200,
        -123000,
        "1000000000000000000",
        false
      )
    );
  });
});
