import { ethers } from "hardhat";

async function main() {
  const SwapCalc = await ethers.deployContract("SwapCalculator");
  await SwapCalc.waitForDeployment();

  console.log(await SwapCalc.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
