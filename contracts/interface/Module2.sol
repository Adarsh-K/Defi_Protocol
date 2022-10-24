// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface Module2 {
    event CardBanished(uint256 indexed cardId);

    function createCard(uint256 amount) external returns(uint256);

    function banishCard(uint256 cardId) external;
}