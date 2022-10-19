const { expect } = require("chai");

describe("Contract deployment", () => {
  let defiTokenFactory, defiProtocolFactory, defiToken, owner, user1, user2, users;

  before(async () => {
    defiTokenFactory = await ethers.getContractFactory("DefiToken");
    defiProtocolFactory = await ethers.getContractFactory("DefiProtocol");
  });

  beforeEach(async () => {
    [owner, user1, user2, ...users] = await ethers.getSigners();
    defiToken = await defiTokenFactory.deploy("DefiToken", "DFT", 1000000);
    await defiToken.deployed();
  });

  describe("DefiToken deployment", () => {
    it("Check owner's balance equal the total minted tokens", async () => {
      expect(await defiToken.balanceOf(owner.address)).equal(1000000);
    });
  });

  describe("DefiProtocol", () => {
    let defiProtocol;

    beforeEach(async () => {
      defiProtocol = await defiProtocolFactory.deploy(defiToken.address);
      await defiProtocol.deployed();
    });

    describe("Staking-Unstaking", () => {
      beforeEach(async () => {
        await defiToken.transfer(user1.address, 100);
      });

      it("Users balance setup", async () => {
        expect(await defiToken.balanceOf(user1.address)).equal(100);
      });
  
      it("Unsuccessful Stake", async () => {
        await defiToken.connect(user1).approve(defiProtocol.address, 50);
        await expect(defiProtocol.connect(user1).stake(80)).to.be.reverted;
        expect(await defiToken.balanceOf(user1.address)).equal(100);
      });

      describe("Successful Stake", () => {
        beforeEach(async () => {
          await defiToken.connect(user1).approve(defiProtocol.address, 50);
          await expect(defiProtocol.connect(user1).stake(50)).to.be.not.reverted;
          expect(await defiToken.balanceOf(user1.address)).equal(50);
        });

        it("Unsuccessful Unstake", async () => {
          await expect(defiProtocol.connect(user1).unstake(60)).to.be.reverted;
          expect(await defiToken.balanceOf(user1.address)).equal(50);
        });

        it("Successful Unstake", async () => {
          await expect(defiProtocol.connect(user1).unstake(10)).to.be.not.reverted;
          expect(await defiToken.balanceOf(user1.address)).equal(60);
        });
      })
    });
  });
});