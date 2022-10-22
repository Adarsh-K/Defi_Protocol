const { ethers, upgrades } = require('hardhat');

async function main() {
  let admin1, admin2;
  // To keep it in the same format as our tests: [owner, user1, user2, admin1, admin2, ...users]
  [, , , admin1, admin2] = await ethers.getSigners();

  const defiTokenFactory = await ethers.getContractFactory("DefiToken");
  const defiToken = await defiTokenFactory.deploy( "DefiToken", "DFT", "100000");
  console.log("Token deployed to:", defiToken.address);

  const defiCardFactory = await ethers.getContractFactory("DefiCard");
  const defiCard = await defiCardFactory.deploy( "DefiCard", "DCT");
  console.log("Card deployed to:", defiCard.address);

  const defiProtocolFactory = await ethers.getContractFactory("DefiProtocol");
  const defiProtocol = await upgrades.deployProxy(defiProtocolFactory, [
    defiToken.address,
    defiCard.address,
    [admin1.address, admin2.address],
    2
  ], { initializer: "initialize" });
  await defiProtocol.deployed();
  console.log("Protocol deployed to:", defiProtocol.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
