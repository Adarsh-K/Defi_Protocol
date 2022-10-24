// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface Module1 {
    event AdminConfirmedEmergency(address indexed user);
    event AdminRevokedEmergency(address indexed user);
    event AdminAddedBlacklist(address indexed user);
    event AdminUnstakedUser(address indexed user);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Locked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 index);
    event ClaimedAll(address indexed user);

    function confirmEmergencyPanic() external;

    function revokeEmergencyPanic() external;

    function addUserToBlacklist(address userAddress) external;

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;

    function unstakeUser(address userAddress, uint256 amount) external;

    function lock(uint256 amount) external;

    function claim(uint256 index) external;

    function claimAll() external;

    function getTotalVestingSchedules() view external returns(uint256);
}