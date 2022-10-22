import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');

const config: HardhatUserConfig = {
  solidity: "0.8.17",
};

export default config;
