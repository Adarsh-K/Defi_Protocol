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

    constructor(address token) {
        require(token != address(0x0));
        _token = IERC20(token);
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
        if (vestingDurationMonths >= 12) {
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
