import { ethers } from "hardhat";
import { Pool__factory } from "./types";

const poolAddress = "0x92e305a63646e76bdd3681f7ece7529cd4e8ed5b";
const amount = 10000000000000000000000n;
const range = 0.1;
const zeroForOne = true;

async function main() {
  const Zap = await ethers.getContractAt(
    "SwapCalculator",
    "0x4e1502ce58574F53F0577C620f86206C4892dfbd"
  );

  let provider: any = ethers.provider;
  const pool = Pool__factory.connect(poolAddress, provider);

  const currentTick = Number((await pool.slot0()).tick);
  const spacing = Number(await pool.tickSpacing());

  // tick to price
  const currentPrice = Math.pow(1.0001, currentTick);

  const upperPrice = (1 + range) * currentPrice;
  const lowerPrice = (1 - range) * currentPrice;

  // convert back to tick
  let tickUpper = Math.log(upperPrice) / Math.log(1.0001);
  let tickLower = Math.log(lowerPrice) / Math.log(1.0001);

  // ensure tick spacing is respected, will always round down to the lowest tick
  tickUpper = Math.floor(tickUpper / spacing) * spacing;
  tickLower = Math.floor(tickLower / spacing) * spacing;

  console.log(
    await Zap.calcSwap.staticCall(
      poolAddress,
      tickLower,
      tickUpper,
      amount,
      zeroForOne
    )
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
