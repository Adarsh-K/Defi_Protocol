const { expect } = require("chai");

describe("Contract deployment", () => {
  let defiTokenFactory, defiProtocolFactory, defiToken, owner, user1, user2, admin1, admin2, users;

  before(async () => {
    defiTokenFactory = await ethers.getContractFactory("DefiToken");
    defiCardFactory = await ethers.getContractFactory("DefiCard");
    defiProtocolFactory = await ethers.getContractFactory("DefiProtocol");
  });

  beforeEach(async () => {
    [owner, user1, user2, admin1, admin2, ...users] = await ethers.getSigners();

    defiToken = await defiTokenFactory.deploy("DefiToken", "DFT", 1000000);
    await defiToken.deployed();

    const vrfCoordinatorGoerli = "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D";
    const subId = 1;
    const keyHashGoerli = "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15";
    defiCard = await defiCardFactory.deploy("DefiCard", "DFC", vrfCoordinatorGoerli, subId, keyHashGoerli);
    await defiCard.deployed();
  });

  describe("DefiToken deployment", () => {
    it("Check owner's balance equal the total minted tokens", async () => {
      expect(await defiToken.balanceOf(owner.address)).equal(1000000);
    });
  });

  describe("DefiProtocol", () => {
    let defiProtocol;

    beforeEach(async () => {
      defiProtocol = await upgrades.deployProxy(defiProtocolFactory, [
        defiToken.address,
        defiCard.address,
        [admin1.address, admin2.address],
        2
      ], { initializer: "initialize" });
      await defiProtocol.deployed();

      await defiToken.transferOwnership(defiProtocol.address);
      await defiCard.transferOwnership(defiProtocol.address);
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
          await expect(defiProtocol.connect(user1).stake(50)).to.emit(defiProtocol, "Staked").withArgs(user1.address, 50);
          expect(await defiToken.balanceOf(user1.address)).equal(50);
        });

        it("Unsuccessful Unstake", async () => {
          await expect(defiProtocol.connect(user1).unstake(60)).to.be.revertedWith("Insufficient Stake");
          expect(await defiToken.balanceOf(user1.address)).equal(50);
        });

        it("Successful Unstake", async () => {
          await expect(defiProtocol.connect(user1).unstake(10)).to.emit(defiProtocol, "Unstaked").withArgs(user1.address, 10);
          expect(await defiToken.balanceOf(user1.address)).equal(60);
        });

        it("Unstake more than once", async () => {
          await expect(defiProtocol.connect(user1).unstake(10)).to.emit(defiProtocol, "Unstaked").withArgs(user1.address, 10);
          expect(await defiToken.balanceOf(user1.address)).equal(60);
          await expect(defiProtocol.connect(user1).unstake(30)).to.emit(defiProtocol, "Unstaked").withArgs(user1.address, 30);
          expect(await defiToken.balanceOf(user1.address)).equal(90);
          await expect(defiProtocol.connect(user1).unstake(20)).to.be.revertedWith("Insufficient Stake");
          expect(await defiToken.balanceOf(user1.address)).equal(90);
        });
      })
    });

    describe("Locking-Vesting", () => {
      beforeEach(async () => {
        await defiToken.transfer(user1.address, 360);
        expect(await defiToken.balanceOf(user1.address)).equal(360);

        await defiToken.connect(user1).approve(defiProtocol.address, 360);
        await expect(defiProtocol.connect(user1).lock(120)).to.emit(defiProtocol, "Locked").withArgs(user1.address, 120);
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
        await expect(defiProtocol.connect(user1).claim(0)).to.emit(defiProtocol, "Claimed").withArgs(user1.address, 0);
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
        await expect(defiProtocol.connect(user1).claim(0)).to.emit(defiProtocol, "Claimed").withArgs(user1.address, 0);
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
        await expect(defiProtocol.connect(user1).claim(0)).to.emit(defiProtocol, "Claimed").withArgs(user1.address, 0);
        expect(await defiToken.balanceOf(user1.address)).equal(120 + 240);
      });

      describe("User1's 2nd Vesting Schedule", () => {
        beforeEach(async () => {
          const fiveMonths = 5 * 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [fiveMonths]);
          await ethers.provider.send("evm_mine");

          await expect(defiProtocol.connect(user1).lock(240)).to.emit(defiProtocol, "Locked").withArgs(user1.address, 240);
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
          await expect(defiProtocol.connect(user1).claim(1)).to.emit(defiProtocol, "Claimed").withArgs(user1.address, 1);
          expect(await defiToken.balanceOf(user1.address)).equal(40);
        });

        it("User1 can claim all 360 tokens", async () => {
          const twoYear = 2 * 12 * 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [twoYear]);
          await ethers.provider.send("evm_mine");
          await expect(defiProtocol.connect(user1).claimAll()).to.emit(defiProtocol, "ClaimedAll").withArgs(user1.address);
          expect(await defiToken.balanceOf(user1.address)).equal(120 + 240);
        });

        it("Claim more than once", async () => {
          const twoYear = 2 * 12 * 31 * 24 * 60 * 60;
          await ethers.provider.send("evm_increaseTime", [twoYear]);
          await ethers.provider.send("evm_mine");
          await expect(defiProtocol.connect(user1).claimAll()).to.emit(defiProtocol, "ClaimedAll").withArgs(user1.address);
          expect(await defiToken.balanceOf(user1.address)).equal(120 + 240);

          expect(await defiProtocol.getAllUserVestedTokens(user1.address)).equal(360);
          await expect(defiProtocol.connect(user1).claimAll()).to.emit(defiProtocol, "ClaimedAll").withArgs(user1.address);
          expect(await defiToken.balanceOf(user1.address)).equal(360);
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
          await expect(defiProtocol.connect(admin2).confirmEmergencyPanic()).to.emit(defiProtocol, "AdminConfirmedEmergency").withArgs(admin2.address);

          await expect(defiProtocol.connect(admin2).unstakeUser(user1.address, 100)).to.be.revertedWith("Not an emergency");
          expect(await defiToken.balanceOf(user1.address)).equal(0);
        });

        it("Admins can unstake if emergency", async() => {
          await expect(defiProtocol.connect(admin1).confirmEmergencyPanic()).to.emit(defiProtocol, "AdminConfirmedEmergency").withArgs(admin1.address);
          await expect(defiProtocol.connect(admin2).confirmEmergencyPanic()).to.emit(defiProtocol, "AdminConfirmedEmergency").withArgs(admin2.address);

          await expect(defiProtocol.connect(admin2).unstakeUser(user1.address, 100)).to.emit(defiProtocol, "AdminUnstakedUser").withArgs(user1.address);
          expect(await defiToken.balanceOf(user1.address)).equal(100);
        });

        it("Unstake user more than once", async () => {
          await expect(defiProtocol.connect(admin1).confirmEmergencyPanic()).to.emit(defiProtocol, "AdminConfirmedEmergency").withArgs(admin1.address);
          await expect(defiProtocol.connect(admin2).confirmEmergencyPanic()).to.emit(defiProtocol, "AdminConfirmedEmergency").withArgs(admin2.address);

          await expect(defiProtocol.connect(admin2).unstakeUser(user1.address, 50)).to.emit(defiProtocol, "AdminUnstakedUser").withArgs(user1.address);
          expect(await defiToken.balanceOf(user1.address)).equal(50);
          await expect(defiProtocol.connect(admin2).unstakeUser(user1.address, 50)).to.emit(defiProtocol, "AdminUnstakedUser").withArgs(user1.address);
          expect(await defiToken.balanceOf(user1.address)).equal(100);
          await expect(defiProtocol.connect(admin2).unstakeUser(user1.address, 10)).to.be.revertedWith("Insufficient Stake");
          expect(await defiToken.balanceOf(user1.address)).equal(100);
        });
      });

      it("Only Admin can add a user to blacklist", async () => {
        await defiToken.transfer(user2.address, 100);
        await defiToken.connect(user2).approve(defiProtocol.address, 100);

        await expect(defiProtocol.connect(user1).addUserToBlacklist(user2.address)).to.be.revertedWith("Not an Admin");

        await defiProtocol.connect(user2).lock(100);
        expect (await defiProtocol.getNumUserVestingSchedules(user2.address)).equal(1);
      });

      it("Even one admin can add a user to blacklist", async () => {
        await defiToken.transfer(user2.address, 100);
        await defiToken.connect(user2).approve(defiProtocol.address, 100);

        await expect(defiProtocol.connect(admin1).addUserToBlacklist(user2.address)).to.emit(defiProtocol, "AdminAddedBlacklist").withArgs(user2.address);

        await expect(defiProtocol.connect(user2).lock(100)).to.be.revertedWith("Blacklisted users can't lock");
        expect (await defiProtocol.getNumUserVestingSchedules(user2.address)).equal(0);
      });

      it("Non-admin not allowed to confirm EmergencyPanic", async () => {
        await expect(defiProtocol.connect(user1).confirmEmergencyPanic()).to.be.revertedWith("Not an Admin");
      });

      it("Admin can confirm EmergencyPanic only once", async () => {
        await expect(defiProtocol.connect(admin1).confirmEmergencyPanic()).to.emit(defiProtocol, "AdminConfirmedEmergency").withArgs(admin1.address);
        await expect(defiProtocol.connect(admin1).confirmEmergencyPanic()).to.be.revertedWith("Admin already confirmed EmergencyPanic");
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

        it("An Admin can't confirm EmergencyPanic more than once", async () => {
          expect(await defiToken.balanceOf(user1.address)).equal(0);

          await defiProtocol.connect(admin1).confirmEmergencyPanic();
          await expect(defiProtocol.connect(admin1).confirmEmergencyPanic()).to.be.rejectedWith("Admin already confirmed EmergencyPanic");
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

          // Revoked
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

    // Since this is a local test VRF Coordinator will not respond.
    // describe("Card", () => {
    //   beforeEach(async () => {
    //     await defiToken.transfer(user1.address, 200);
    //     await defiToken.connect(user1).approve(defiProtocol.address, 100);
    //   });

    //   describe("Create Card", () => {
    //     beforeEach(async () => {
    //       await defiProtocol.connect(user1).createCard(50);
    //     });

    //     it("Can't create card of more initialPower than approved", async () => {
    //       await expect(defiProtocol.connect(user1).createCard(150)).to.be.reverted;
    //     });

    //     it("User1 owns card1", async () => {
    //       expect(await defiCard.ownerOf(1)).equal(user1.address);
    //       expect(await defiToken.balanceOf(user1.address)).equal(150);
    //     });

    //     it("User can create multiple cards", async () => {
    //       await defiProtocol.connect(user1).createCard(50);
    //       expect(await defiCard.ownerOf(2)).equal(user1.address);
    //       expect(await defiToken.balanceOf(user1.address)).equal(100);
    //     });

    //     it("User can sell card to 3rd party without using the DefiProtocol", async () => {
    //       await defiToken.transfer(user2.address, 150);

    //       // Simulating a 3rd party exchange
    //       await defiToken.connect(user2).transfer(user1.address, 150);
    //       await defiCard.connect(user1).transferFrom(user1.address, user2.address, 1);
    //       expect(await defiToken.balanceOf(user1.address)).equal(150 + 150);
    //       expect(await defiToken.balanceOf(user2.address)).equal(0);

    //       expect(await defiCard.ownerOf(1)).equal(user2.address);
    //       expect(await defiCard.ownerOf(1)).not.equal(user1.address);
    //     });
    //   });

    //   describe("Banish Card", () => {
    //     beforeEach(async () => {
    //       await defiProtocol.connect(user1).createCard(50);
    //     });

    //     it("Fail banish from another user", async () => {
    //       expect(await defiCard.ownerOf(1)).equal(user1.address);
    //       await defiCard.connect(user1).setApprovalForAll(defiProtocol.address, true);

    //       await expect(defiProtocol.connect(user2).banishCard(1))
    //         .to.be.revertedWith("Only card owner can banish the card"); // user2 not owner of card1

    //       expect(await defiCard.ownerOf(1)).equal(user1.address);
    //       expect(await defiToken.balanceOf(user1.address)).equal(150);
    //     });

    //     it("Successfully banish", async () => {
    //       expect(await defiCard.ownerOf(1)).equal(user1.address);
    //       await defiCard.connect(user1).setApprovalForAll(defiProtocol.address, true);

    //       await expect(defiProtocol.connect(user1).banishCard(1)).to.emit(defiProtocol, "CardBanished").withArgs(1);

    //       expect(await defiCard.ownerOf(1)).not.equal(user1.address);
    //       expect(await defiToken.balanceOf(user1.address)).equal(200);
    //     });

    //     it("Card gains power everyday", async () => {
    //       expect(await defiCard.ownerOf(1)).equal(user1.address);
    //       await defiCard.connect(user1).setApprovalForAll(defiProtocol.address, true);

    //       const twoDays = 2.5 * 24 * 60 * 60;
    //       await ethers.provider.send("evm_increaseTime", [twoDays]);
    //       await ethers.provider.send("evm_mine");
    //       await expect(defiProtocol.connect(user1).banishCard(1)).to.emit(defiProtocol, "CardBanished").withArgs(1);

    //       expect(await defiCard.ownerOf(1)).not.equal(user1.address);
    //       console.log("User1 balance: " + (await defiToken.balanceOf(user1.address)).toString());
    //     });
    //   });
    // });
  });
});
