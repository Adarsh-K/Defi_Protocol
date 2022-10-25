// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract DefiCard is ERC721, Ownable, ReentrancyGuard, VRFConsumerBaseV2 {
    using SafeMath for uint256;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event MintedCard(uint256 indexed cardId, address indexed user, uint256 initialPower);

    struct CardInfo {
        uint256 cardId;
        address userAddress;
        uint256 initialPower;
    }

    struct CardData {
        uint256 mintedOn;
        uint256 initialPower;
        uint8 color;
        uint8 symbol;
        uint8 tier;
        uint8 evolution;
    }

    VRFCoordinatorV2Interface private immutable _coordinator;
    uint64 private immutable _subscriptionId;
    bytes32 private immutable _keyHash;
    uint32 private constant _callbackGasLimit = 1000000;
    uint16 private constant _requestConfirmations = 3;
    uint32 private constant _numWords = 1;

    mapping(uint256 => CardInfo) private _requestIdToCardInfo;
    mapping(uint256 => CardData) private _cards;

    constructor(string memory _name, string memory _symbol, address coordinator, uint64 subscriptionId, bytes32 keyHash)
        ERC721(_name, _symbol)
        VRFConsumerBaseV2(coordinator)
    {
        _coordinator = VRFCoordinatorV2Interface(coordinator);
        _subscriptionId = subscriptionId;
        _keyHash = keyHash;
    }


    function mint(uint256 cardId, address userAddress, uint256 initialPower) external onlyOwner nonReentrant returns(uint256 requestId) {
        requestId = _coordinator.requestRandomWords(
            _keyHash,
            _subscriptionId,
            _requestConfirmations,
            _callbackGasLimit,
            _numWords
        );
        _requestIdToCardInfo[requestId] = CardInfo(cardId, userAddress, initialPower);
        emit RequestSent(requestId, _numWords);
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        CardInfo storage requestCardInfo = _requestIdToCardInfo[_requestId];
        require(requestCardInfo.userAddress != address(0), "Request not found");

        _safeMint(requestCardInfo.userAddress, requestCardInfo.cardId);
        emit MintedCard(requestCardInfo.cardId, requestCardInfo.userAddress, requestCardInfo.initialPower);

        uint8 color = uint8(_randomWords[0].mod(3).add(1));
        uint256 _symbol = _randomWords[0].mod(4);
        uint8 symbol = uint8(_symbol.mul(2).add(_symbol.div(3)));
        uint8 tier = uint8(_randomWords[0].mod(5).add(1));
        uint8 evolution = uint8(_randomWords[0].mod(100).add(1));

        _cards[requestCardInfo.cardId] = CardData(block.timestamp, requestCardInfo.initialPower, color, symbol, tier, evolution);
        emit RequestFulfilled(_requestId, _randomWords);
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
