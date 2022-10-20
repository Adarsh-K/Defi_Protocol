// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DefiProtocol {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingSchedule{
        uint256 start;
        uint256 amount;
        uint256 claimed;
    }

    IERC20 immutable private _token;
    mapping(address => uint256) private _stakes;

    uint256 private _numVestingSchedules;
    mapping(bytes32 => VestingSchedule) private _vestingSchedules;
    mapping(address => uint256) private _userTotalVestingSchedules;

    uint256 public confirmedEmergencyPanic;
    uint256 public requiredConfirmedEmergencyPanic;
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public adminConfirmations;

    modifier adminOnly() {
        require(isAdmin[msg.sender], "Not an Admin");
        _;
    }

    constructor(address token, address[] memory _admins, uint256 _requiredConfirmedEmergencyPanic) {
        require(token != address(0x0));
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
        _token = IERC20(token);
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

    function stake(uint256 amount) public {
        _token.transferFrom(msg.sender, address(this), amount); // safe?
        _stakes[msg.sender] = _stakes[msg.sender].add(amount);
    }

    function unstake(uint256 amount) public {
        require(_stakes[msg.sender] >= amount, "Insufficient Stake");
        _token.transfer(msg.sender, amount);
        _stakes[msg.sender] = _stakes[msg.sender].sub(amount);
    }

    function lock(uint256 amount) public {
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
        _token.safeTransfer(payable(msg.sender), unclaimedTokens);
    }

    function claimAll() public {
        uint256 totalClaimableTokens;
        for (uint256 index = 0; index < getNumUserVestingSchedules(msg.sender); index++) {
            uint256 unclaimedTokens = getUnclaimedToken(msg.sender, index);
            VestingSchedule storage vestingSchedule = _vestingSchedules[getUserVestingIdByIndex(msg.sender, index)];
            vestingSchedule.claimed = vestingSchedule.claimed.add(unclaimedTokens);
            totalClaimableTokens = totalClaimableTokens.add(unclaimedTokens);
        }
        _token.safeTransfer(payable(msg.sender), totalClaimableTokens);
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
