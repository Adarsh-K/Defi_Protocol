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
  // The below is for Goerli testnet
  const vrfCoordinatorGoerli = "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D";
  const subId = 1; // Change subId based on your actual subcriptionId as on the Chainlink dashboard
  const keyHashGoerli = "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15";
  const defiCard = await defiCardFactory.deploy("DefiCard", "DFC", vrfCoordinatorGoerli, subId, keyHashGoerli);
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

  // After Creating a subscription on the Chainlink VRF Dashboard
  // Fund it &
  // Add a DefiCard as it consumer
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
