const { expect } = require("chai");

describe("Contract deployment", () => {
  let defiTokenFactory, defiProtocolFactory, defiToken, owner, user1, user2, admin1, admin2, users;

  before(async () => {
    defiTokenFactory = await ethers.getContractFactory("DefiToken");
    defiProtocolFactory = await ethers.getContractFactory("DefiProtocol");
  });

  beforeEach(async () => {
    [owner, user1, user2, admin1, admin2, ...users] = await ethers.getSigners();
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
      defiProtocol = await defiProtocolFactory.deploy(defiToken.address, [admin1.address, admin2.address], 2);
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

    describe("Locking-Vesting", () => {
      beforeEach(async () => {
        await defiToken.transfer(user1.address, 360);
        expect(await defiToken.balanceOf(user1.address)).equal(360);

        await defiToken.connect(user1).approve(defiProtocol.address, 360);
        await defiProtocol.connect(user1).lock(120);
      });

      it("User1 should have 1 Vesting Schedule", async () => {
        expect(await defiToken.balanceOf(user1.address)).equal(360 - 120);
        expect(await defiProtocol.getTotalVestingSchedules()).equal(1);
        expect(await defiProtocol.getNumUserVestingSchedules(user1.address)).equal(1);
      });

      it("User1 should have 0 tokens vested", async () => {
        expect(await defiProtocol.getUserVestedTokensByIndex(user1.address, 0)).equal(0);
      });

      it("User1 can't claim any tokens", async () => {
        await defiProtocol.connect(user1).claim(0);
        expect(await defiToken.balanceOf(user1.address)).equal(240);
      });

      it("User1 should have 60 vested tokens", async () => {
        const sixMonths = 6 * 31 * 24 * 60 * 60;
        await ethers.provider.send("evm_increaseTime", [sixMonths]);
        await ethers.provider.send("evm_mine");
        expect(await defiProtocol.getUserVestedTokensByIndex(user1.address, 0)).equal(60);
      });

      it("User1 can claim 60 tokens", async () => {
        const sixMonths = 6 * 31 * 24 * 60 * 60;
        await ethers.provider.send("evm_increaseTime", [sixMonths]);
        await ethers.provider.send("evm_mine");
        await defiProtocol.connect(user1).claim(0);
        expect(await defiToken.balanceOf(user1.address)).equal(60 + 240);
      });

      it("User1 should have all 120 tokens vested", async () => {
        const oneYear = 12 * 31 * 24 * 60 * 60;
        await ethers.provider.send("evm_increaseTime", [oneYear]);
        await ethers.provider.send("evm_mine");
        expect(await defiProtocol.getUserVestedTokensByIndex(user1.address, 0)).equal(120);
      });

      it("User1 can claim all 120 tokens", async () => {
        const oneYear = 12 * 31 * 24 * 60 * 60;
        await ethers.provider.send("evm_increaseTime", [oneYear]);
        await ethers.provider.send("evm_mine");
        await defiProtocol.connect(user1).claim(0);
        expect(await defiToken.balanceOf(user1.address)).equal(120 + 240);
      });

      describe("User1's 2nd Vesting Schedule", () => {
        beforeEach(async () => {
          const fiveMonths = 5 * 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [fiveMonths]);
          await ethers.provider.send("evm_mine");

          await defiProtocol.connect(user1).lock(240);
          expect(await defiToken.balanceOf(user1.address)).equal(0);
        });

        it("User1 should have 2 Vesting Schedules", async () => {
          expect(await defiProtocol.getTotalVestingSchedules()).equal(2);
          expect(await defiProtocol.getNumUserVestingSchedules(user1.address)).equal(2);
        });

        it("User1 should have 80 (60 + 20) vested tokens", async () => {
          const oneMonth = 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [oneMonth]);
          await ethers.provider.send("evm_mine");
          expect(await defiProtocol.getAllUserVestedTokens(user1.address)).equal(80);
        });

        it("User1 can claim all 40 tokens", async () => {
          const twoMonths = 2 * 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [twoMonths]);
          await ethers.provider.send("evm_mine");
          await defiProtocol.connect(user1).claim(1);
          expect(await defiToken.balanceOf(user1.address)).equal(40);
        });

        it("User1 can claim all 360 tokens", async () => {
          const twoYear = 2 * 12 * 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [twoYear]);
          await ethers.provider.send("evm_mine");
          await defiProtocol.connect(user1).claimAll();
          expect(await defiToken.balanceOf(user1.address)).equal(120 + 240);
        });
      });
    });

    describe("Multisig Admin", () => {
      describe("UnstakeUser", () => {
        beforeEach(async () => {
          await defiToken.transfer(user1.address, 100);
          await defiToken.connect(user1).approve(defiProtocol.address, 100);
          await defiProtocol.connect(user1).stake(100);
        });

        it("Non-admin can't unstake for another user", async () => {
          await expect(defiProtocol.connect(user2).unstakeUser(user1.address, 100)).to.be.reverted;
          expect(await defiToken.balanceOf(user1.address)).equal(0);
        });

        it("Not unstaked unless required unmber of admins had confirmed EmergencyPanic", async() => {
          await defiProtocol.connect(admin2).confirmEmergencyPanic();

          await expect(defiProtocol.connect(admin2).unstakeUser(user1.address, 100)).to.be.reverted;
          expect(await defiToken.balanceOf(user1.address)).equal(0);
        });

        it("Admins can unstake if emergency", async() => {
          await defiProtocol.connect(admin1).confirmEmergencyPanic();
          await defiProtocol.connect(admin2).confirmEmergencyPanic();

          await expect(defiProtocol.connect(admin2).unstakeUser(user1.address, 100)).to.be.not.reverted;
          expect(await defiToken.balanceOf(user1.address)).equal(100);
        });
      });

      it("Non-admin not allowed to confirm EmergencyPanic", async () => {
        await expect(defiProtocol.connect(user1).confirmEmergencyPanic()).to.be.reverted;
      });

      it("Admin can confirm EmergencyPanic only once", async () => {
        await expect(defiProtocol.connect(admin1).confirmEmergencyPanic()).to.be.not.reverted;
        await expect(defiProtocol.connect(admin1).confirmEmergencyPanic()).to.be.reverted;
      });

      describe("Unlock tokens after EmergencyPanic", () => {
        beforeEach(async () => {
          await defiToken.transfer(user1.address, 100);
          await defiToken.connect(user1).approve(defiProtocol.address, 100);
          await defiProtocol.connect(user1).lock(100);
        });

        it("Users can't claim locked tokens unless all the required number of admins (2) have confirmed EmergencyPanic", async () => {
          expect(await defiToken.balanceOf(user1.address)).equal(0);

          await defiProtocol.connect(admin1).confirmEmergencyPanic();
          expect(await defiProtocol.confirmedEmergencyPanic()).equal(1);

          await defiProtocol.connect(user1).claimAll();
          expect(await defiToken.balanceOf(user1.address)).equal(0);
        });

        it("Users should be able to claim locked tokens when all the required number of admins (2) have confirmed EmergencyPanic", async () => {
          expect(await defiToken.balanceOf(user1.address)).equal(0);

          await defiProtocol.connect(admin1).confirmEmergencyPanic();
          await defiProtocol.connect(admin2).confirmEmergencyPanic();
          expect(await defiProtocol.confirmedEmergencyPanic()).equal(2);

          await defiProtocol.connect(user1).claimAll();
          expect(await defiToken.balanceOf(user1.address)).equal(100);
        });

        it("Revoked: Users can't claim locked tokens unless all the required number of admins (2) have confirmed EmergencyPanic", async () => {
          expect(await defiToken.balanceOf(user1.address)).equal(0);

          await defiProtocol.connect(admin1).confirmEmergencyPanic();
          await defiProtocol.connect(admin2).confirmEmergencyPanic();
          expect(await defiProtocol.confirmedEmergencyPanic()).equal(2);

          await defiProtocol.connect(admin1).revokeEmergencyPanic();
          expect(await defiProtocol.confirmedEmergencyPanic()).equal(1);

          // At least those tokens which are vested can be claimed
          const sixMonths = 6 * 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [sixMonths]);
          await ethers.provider.send("evm_mine");

          // Using claim instead of claimAll, just to test it as well
          await defiProtocol.connect(user1).claim(0);
          expect(await defiToken.balanceOf(user1.address)).equal(50);
        });
      });
    });
  });
});
