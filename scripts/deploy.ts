const { ethers, upgrades } = require('hardhat');

async function main() {
  let admin1, admin2;
  [, , , admin1, admin2] = await ethers.getSigners();

  // Add admins below, you may also change the number of admins
  // const admin1 = "0x";
  // const admin2 = "0x";

  const defiTokenFactory = await ethers.getContractFactory("DefiToken");
  const defiToken = await defiTokenFactory.deploy( "DefiToken", "DFT", "100000");
  await defiToken.deployed();
  console.log("Token deployed to:", defiToken.address);

  const defiCardFactory = await ethers.getContractFactory("DefiCard");
  const defiCard = await defiCardFactory.deploy( "DefiCard", "DCT");
  await defiCard.deployed();
  console.log("Card deployed to:", defiCard.address);

  const defiProtocolFactory = await ethers.getContractFactory("DefiProtocol");
  const defiProtocol = await upgrades.deployProxy(defiProtocolFactory, [
    defiToken.address,
    defiCard.address,
    // [admin1, admin2],
    [admin1.address, admin2.address],
    2
  ], { initializer: "initialize" });
  await defiProtocol.deployed();
  console.log("Protocol deployed to:", defiProtocol.address);

  await defiToken.transferOwnership(defiProtocol.address);
  await defiCard.transferOwnership(defiProtocol.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
