// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./DefiCard.sol";
import "./DefiToken.sol";

import "hardhat/console.sol";

contract DefiProtocol is IERC721ReceiverUpgradeable, Initializable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

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

    modifier adminOnly() {
        require(isAdmin[msg.sender], "Not an Admin");
        _;
    }

    function initialize(address token, address card, address[] memory _admins, uint256 _requiredConfirmedEmergencyPanic) initializer public {
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
    }

    function createCard(uint256 amount) external returns(uint256) {
        _cardIds.increment();
        _token.transferFrom(msg.sender, address(this), amount);
        _card.mint(_cardIds.current(), msg.sender, amount);
        return _cardIds.current();
    }

    function banishCard(uint256 cardId) external {
        require(_card.ownerOf(cardId) == msg.sender, "Only card owner can banish the card");
        _card.safeTransferFrom(msg.sender, address(this), cardId);
        _token.mint(msg.sender, _card.getPower(cardId));
        // TODO: burn cardId
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function isEmergencyPanic() view public returns(bool) {
        return confirmedEmergencyPanic >= requiredConfirmedEmergencyPanic;
    }

    function confirmEmergencyPanic() public adminOnly {
        require(!adminConfirmations[msg.sender], "Admin already confirmed EmergencyPanic");
        adminConfirmations[msg.sender] = true;
        confirmedEmergencyPanic = confirmedEmergencyPanic.add(1);
    }

    function revokeEmergencyPanic() public adminOnly {
        require(adminConfirmations[msg.sender], "No confirmed EmergencyPanic from Admin yet");
        adminConfirmations[msg.sender] = false;
        confirmedEmergencyPanic = confirmedEmergencyPanic.sub(1);
    }

    // Even a single admin can add a user to blacklist
    function addUserToBlacklist(address userAddress) public adminOnly {
        require(!blackList[userAddress], "User already blacklisted");
        blackList[userAddress] = true;
    }

    function stake(uint256 amount) public {
        _token.transferFrom(msg.sender, address(this), amount); // safe?
        _stakes[msg.sender] = _stakes[msg.sender].add(amount);
    }

    function unstake(uint256 amount) public {
        require(_stakes[msg.sender] >= amount, "Insufficient Stake");
        _token.transfer(msg.sender, amount);
        _stakes[msg.sender] = _stakes[msg.sender].sub(amount);
    }

    function unstakeUser(address userAddress, uint256 amount) public adminOnly {
        require(_stakes[userAddress] >= amount, "Insufficient Stake");
        require(isEmergencyPanic(), "Not an emergency");
        _token.transfer(userAddress, amount);
        _stakes[userAddress] = _stakes[userAddress].sub(amount);
    }

    function lock(uint256 amount) public {
        require(!blackList[msg.sender], "Blacklisted users can't lock");
        require(amount > 0, "Locked amount should be > 0");
        _token.transferFrom(msg.sender, address(this), amount);
        _vestingSchedules[getUserNextVestingId(msg.sender)] = VestingSchedule(
            block.timestamp,
            amount,
            0
        );
        _numVestingSchedules = _numVestingSchedules.add(1);
        _userTotalVestingSchedules[msg.sender] = _userTotalVestingSchedules[msg.sender].add(1);
    }

    function claim(uint256 index) public {
        require(index < getNumUserVestingSchedules(msg.sender)); // put it in a modifier
        uint256 unclaimedTokens = getUnclaimedToken(msg.sender, index);

        VestingSchedule storage vestingSchedule = _vestingSchedules[getUserVestingIdByIndex(msg.sender, index)];
        vestingSchedule.claimed = vestingSchedule.claimed.add(unclaimedTokens);
        _token.transfer(payable(msg.sender), unclaimedTokens);
    }

    function claimAll() public {
        uint256 totalClaimableTokens;
        for (uint256 index = 0; index < getNumUserVestingSchedules(msg.sender); index++) {
            uint256 unclaimedTokens = getUnclaimedToken(msg.sender, index);
            VestingSchedule storage vestingSchedule = _vestingSchedules[getUserVestingIdByIndex(msg.sender, index)];
            vestingSchedule.claimed = vestingSchedule.claimed.add(unclaimedTokens);
            totalClaimableTokens = totalClaimableTokens.add(unclaimedTokens);
        }
        _token.transfer(payable(msg.sender), totalClaimableTokens);
    }

    function getUnclaimedToken(address userAddess, uint256 index) view public returns(uint256) {
        uint256 vestedTokens = getUserVestedTokensByIndex(userAddess, index);
        VestingSchedule storage vestingSchedule = _vestingSchedules[getUserVestingIdByIndex(userAddess, index)];
        return vestedTokens.sub(vestingSchedule.claimed);
    }

    function getUserNextVestingId(address userAddress) view internal returns(bytes32) {
        return keccak256(abi.encodePacked(userAddress, _userTotalVestingSchedules[userAddress]));
    }

    function getUserVestingIdByIndex(address userAddress, uint256 index) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(userAddress, index));
    }

    function getTotalVestingSchedules() view external returns(uint256) {
        return _numVestingSchedules;
    }

    function getNumUserVestingSchedules(address userAddress) view public returns(uint256) {
        return _userTotalVestingSchedules[userAddress];
    }

    function getUserVestedTokensByIndex(address userAddress, uint256 index) view public returns(uint256) {
        require(index < getNumUserVestingSchedules(userAddress));
        VestingSchedule storage vestingSchedule = _vestingSchedules[getUserVestingIdByIndex(userAddress, index)]; // extract in function
        uint256 vestingDurationMonths = (block.timestamp.sub(vestingSchedule.start)).div(2_629_746);
        if (vestingDurationMonths >= 12 || isEmergencyPanic()) {
            return vestingSchedule.amount;
        }
        return vestingSchedule.amount.mul(vestingDurationMonths).div(12);
    }

    function getAllUserVestedTokens(address userAddress) view public returns(uint256) {
        uint256 totalVestedTokens;
        for (uint256 index = 0; index < getNumUserVestingSchedules(userAddress); index++) {
            totalVestedTokens = totalVestedTokens.add(getUserVestedTokensByIndex(userAddress, index));
        }
        return totalVestedTokens;
    }
}
