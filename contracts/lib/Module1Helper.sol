// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Module1Helper {
    function _getUserVestingIdByIndex(address userAddress, uint256 index) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(userAddress, index));
    }
}