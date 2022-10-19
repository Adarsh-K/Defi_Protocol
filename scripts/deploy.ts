import { ethers } from "hardhat";

async function main() {
  const defiTokenFactory = await ethers.getContractFactory("DefiToken");
  const defiToken = await defiTokenFactory.deploy( "DefiToken", "DFT", "100");
  console.log("Contract deployed to:", defiToken.address);

  const defiProtocolFactory = await ethers.getContractFactory("DefiProtocol");
  const defiProtocol = await defiProtocolFactory.deploy(defiToken.address);
  console.log("Contract deployed to:", defiProtocol.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
