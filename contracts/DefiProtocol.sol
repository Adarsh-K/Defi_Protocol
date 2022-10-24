// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./DefiCard.sol";
import "./DefiToken.sol";
import "./interface/Module1.sol";
import "./interface/Module2.sol";
import { Module1Helper } from "./lib/Module1Helper.sol";

import "hardhat/console.sol";

contract DefiProtocol is IERC721ReceiverUpgradeable, Initializable, ReentrancyGuardUpgradeable, Module1, Module2 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using AddressUpgradeable for address;

    Counters.Counter private _cardIds;

    struct VestingSchedule{
        uint256 start;
        uint256 amount;
        uint256 claimed;
    }

    DefiToken private _token;
    DefiCard private _card;
    mapping(address => uint256) private _stakes;

    uint256 private _numVestingSchedules;
    mapping(bytes32 => VestingSchedule) private _vestingSchedules;
    mapping(address => uint256) private _userTotalVestingSchedules;

    uint256 public confirmedEmergencyPanic;
    uint256 public requiredConfirmedEmergencyPanic;
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public adminConfirmations;
    mapping(address => bool) public blackList;
    uint256[25] __gap;

    modifier adminOnly() {
        require(isAdmin[msg.sender], "Not an Admin");
        _;
    }

    function initialize(address token, address card, address[] memory _admins, uint256 _requiredConfirmedEmergencyPanic)
        initializer public {
        require(token != address(0));
        require(_admins.length > 1, "At least 2 admins required");
        require(_requiredConfirmedEmergencyPanic > 1
            && _requiredConfirmedEmergencyPanic <= _admins.length, "Invalid required confirmations");

        for (uint256 index = 0; index < _admins.length; index++) {
            address _admin = _admins[index];
            require(_admin != address(0x0), "Invalid Admin");
            require(!isAdmin[_admin], "Already an admin");

            isAdmin[_admin] = true;
        }
        requiredConfirmedEmergencyPanic = _requiredConfirmedEmergencyPanic;
        _token = DefiToken(token);
        _card = DefiCard(card);
        __ReentrancyGuard_init();
    }

    function createCard(uint256 amount) external nonReentrant returns(uint256) {
        _cardIds.increment();
        _token.transferFrom(msg.sender, address(this), amount);
        _card.mint(_cardIds.current(), msg.sender, amount);
        return _cardIds.current();
    }

    function banishCard(uint256 cardId) external nonReentrant {
        require(_card.ownerOf(cardId) == msg.sender, "Only card owner can banish the card");
        _card.safeTransferFrom(msg.sender, address(this), cardId);

        bytes memory data = abi.encodeWithSignature("safeMint(address,uint256)", msg.sender, _card.getPower(cardId));
        bytes memory returndata = address(_token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }

        emit CardBanished(cardId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function isEmergencyPanic() view public returns(bool) {
        return confirmedEmergencyPanic >= requiredConfirmedEmergencyPanic;
    }

    function confirmEmergencyPanic() external adminOnly nonReentrant {
        require(!adminConfirmations[msg.sender], "Admin already confirmed EmergencyPanic");
        adminConfirmations[msg.sender] = true;
        confirmedEmergencyPanic = confirmedEmergencyPanic.add(1);
        emit AdminConfirmedEmergency(msg.sender);
    }

    function revokeEmergencyPanic() external adminOnly nonReentrant {
        require(adminConfirmations[msg.sender], "No confirmed EmergencyPanic from Admin yet");
        adminConfirmations[msg.sender] = false;
        confirmedEmergencyPanic = confirmedEmergencyPanic.sub(1);
        emit AdminRevokedEmergency(msg.sender);
    }

    // Even a single admin can add a user to blacklist
    function addUserToBlacklist(address userAddress) external adminOnly {
        require(!blackList[userAddress], "User already blacklisted");
        blackList[userAddress] = true;
        emit AdminAddedBlacklist(userAddress);
    }

    function stake(uint256 amount) external nonReentrant {
        _token.transferFrom(msg.sender, address(this), amount);
        _stakes[msg.sender] = _stakes[msg.sender].add(amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(_stakes[msg.sender] >= amount, "Insufficient Stake");
        _stakes[msg.sender] = _stakes[msg.sender].sub(amount);
        _token.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function unstakeUser(address userAddress, uint256 amount) external adminOnly nonReentrant {
        require(_stakes[userAddress] >= amount, "Insufficient Stake");
        require(isEmergencyPanic(), "Not an emergency");
        _stakes[userAddress] = _stakes[userAddress].sub(amount);
        _token.transfer(userAddress, amount);
        emit AdminUnstakedUser(userAddress);
    }

    function lock(uint256 amount) external nonReentrant {
        require(!blackList[msg.sender], "Blacklisted users can't lock");
        require(amount > 0, "Locked amount should be > 0");
        _token.transferFrom(msg.sender, address(this), amount);
        _vestingSchedules[Module1Helper._getUserVestingIdByIndex( // Next Vesting
            msg.sender, _userTotalVestingSchedules[msg.sender])] = VestingSchedule(
                block.timestamp,
                amount,
                0
            );
        _numVestingSchedules = _numVestingSchedules.add(1);
        _userTotalVestingSchedules[msg.sender] = _userTotalVestingSchedules[msg.sender].add(1);
        emit Locked(msg.sender, amount);
    }

    function claim(uint256 index) external nonReentrant {
        require(index < getNumUserVestingSchedules(msg.sender)); // put it in a modifier
        uint256 unclaimedTokens = _getUnclaimedToken(msg.sender, index);

        VestingSchedule storage vestingSchedule = _getVestingSchedule(msg.sender, index);
        vestingSchedule.claimed = vestingSchedule.claimed.add(unclaimedTokens);
        _token.transfer(payable(msg.sender), unclaimedTokens);
        emit Claimed(msg.sender, index);
    }

    function claimAll() external nonReentrant {
        uint256 totalClaimableTokens;
        for (uint256 index = 0; index < getNumUserVestingSchedules(msg.sender); index++) {
            uint256 unclaimedTokens = _getUnclaimedToken(msg.sender, index);
            VestingSchedule storage vestingSchedule = _getVestingSchedule(msg.sender, index);
            vestingSchedule.claimed = vestingSchedule.claimed.add(unclaimedTokens);
            totalClaimableTokens = totalClaimableTokens.add(unclaimedTokens);
        }
        _token.transfer(payable(msg.sender), totalClaimableTokens);
        emit ClaimedAll(msg.sender);
    }

    function getTotalVestingSchedules() view external returns(uint256) {
        return _numVestingSchedules;
    }

    function getAllUserVestedTokens(address userAddress) view external returns(uint256) {
        uint256 totalVestedTokens;
        for (uint256 index = 0; index < getNumUserVestingSchedules(userAddress); index++) {
            totalVestedTokens = totalVestedTokens.add(getUserVestedTokensByIndex(userAddress, index));
        }
        return totalVestedTokens;
    }

    function getNumUserVestingSchedules(address userAddress) view public returns(uint256) {
        return _userTotalVestingSchedules[userAddress];
    }

    function getUserVestedTokensByIndex(address userAddress, uint256 index) view public returns(uint256) {
        require(index < getNumUserVestingSchedules(userAddress));
        VestingSchedule storage vestingSchedule = _getVestingSchedule(userAddress, index);
        uint256 vestingDurationMonths = (block.timestamp.sub(vestingSchedule.start)).div(2_629_746);
        if (vestingDurationMonths >= 12 || isEmergencyPanic()) {
            return vestingSchedule.amount;
        }
        return vestingSchedule.amount.mul(vestingDurationMonths).div(12);
    }

    function _getUnclaimedToken(address userAddress, uint256 index) view internal returns(uint256) {
        uint256 vestedTokens = getUserVestedTokensByIndex(userAddress, index);
        VestingSchedule storage vestingSchedule = _getVestingSchedule(userAddress, index);
        return vestedTokens.sub(vestingSchedule.claimed);
    }

    function _getVestingSchedule(address userAddress, uint256 index) view internal returns(VestingSchedule storage) {
        return _vestingSchedules[Module1Helper._getUserVestingIdByIndex(userAddress, index)];
    }
}
