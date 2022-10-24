// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract DefiCard is ERC721, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // TODO set enums for color & symbol

    struct CardData {
        uint256 mintedOn;
        uint256 initialPower;
        uint8 color;
        uint8 symbol;
        uint8 tier;
        uint8 evolution;
    }

    mapping(uint256 => CardData) _cards;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol) {}

    function mint(uint256 cardId, address userAddress, uint256 _initialPower) external onlyOwner nonReentrant {
        _safeMint(userAddress, cardId);

        uint256 random = block.timestamp;
        uint8 color = uint8(random.mod(3).add(1));
        uint256 _symbol = random.mod(4);
        uint8 symbol = uint8(_symbol.mul(2).add(_symbol.div(3)));
        uint8 tier = uint8(random.mod(5).add(1));
        uint8 evolution = uint8(random.mod(100).add(1));

        _cards[cardId] = CardData(block.timestamp, _initialPower, color, symbol, tier, evolution);
    }

    function getPower(uint256 cardId) view external returns(uint256) {
        CardData storage card = _cards[cardId];
        uint256 durationSeconds = block.timestamp.sub(card.mintedOn);
        uint256 durationDays = durationSeconds.div(24 * 60 * 60);
        return card.initialPower + (durationDays * card.evolution * card.initialPower * (card.tier + card.color + card.symbol)).div(100);
    }

    function getCardStats(uint256 cardId) view external returns(uint256, uint256, uint8, uint8, uint8, uint8) {
        CardData storage card = _cards[cardId];
        return (
            card.mintedOn,
            card.initialPower,
            card.color,
            card.tier,
            card.symbol,
            card.evolution
        );
    }
}
