// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DefiCard is ERC721, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    event MintedCard(uint256 indexed cardId, address indexed user, uint256 initialPower);

    struct CardData {
        uint256 mintedOn;
        uint256 initialPower;
        uint8 color;
        uint8 symbol;
        uint8 tier;
        uint8 evolution;
    }

    mapping(uint256 => CardData) private _cards;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol) {}

    function mint(uint256 cardId, address userAddress, uint256 _initialPower) external onlyOwner nonReentrant {
        _safeMint(userAddress, cardId);

        uint256 random = block.timestamp;
        uint8 color = uint8(random.mod(3).add(1)); // Colors: WHITE, BLACK, RED
        uint256 _symbol = random.mod(4); // Symbols: STAR, SWORD, CHICKEN, FLOWER
        uint8 symbol = uint8(_symbol.mul(2).add(_symbol.div(3)));
        uint8 tier = uint8(random.mod(5).add(1)); // Tier: 1 - 5
        uint8 evolution = uint8(random.mod(100).add(1)); // Evolution: 1 - 100%

        // Imp: In prod use Chainlink API for getting random number, see branch chainlink-api
        _cards[cardId] = CardData(block.timestamp, _initialPower, color, symbol, tier, evolution);
        emit MintedCard(cardId, userAddress, _initialPower);
    }

    // Daily gain of cardPower += evolution * (InitialCardPower * (tier number + color + symbol))
    function getPower(uint256 cardId) view external returns(uint256) {
        CardData storage card = _cards[cardId];
        uint256 durationSeconds = block.timestamp.sub(card.mintedOn); // In prod don't use timestamp, use an oracle like Chainlink
        uint256 durationDays = durationSeconds.div(24 * 60 * 60);
        return card.initialPower +
            (durationDays * card.evolution * card.initialPower * (card.tier + card.color + card.symbol)).div(100); // div by 100 as Evolution is a percentage
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
