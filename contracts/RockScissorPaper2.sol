// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

// Импорты для Chainlink VRF v2.5
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Добавлена библиотека ReentrancyGuard

contract RockScissorPaper is VRFConsumerBaseV2Plus, ReentrancyGuard { // Добавлено наследование ReentrancyGuard

    // Минимальная ставка (0.000001 bnb - 1000 gwei)
    uint256 public constant MIN_BET = 0.000001 ether; 

    // Настройки Chainlink VRF v2.5 для BSC Testnet
    uint256 public s_subscriptionId;
    address public vrfCoordinator = 0xDA3b641D438362C440Ac5458c57e00a712b66700; 
    bytes32 public keyHash = 0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26; 
    uint32 public callbackGasLimit = 200000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    // --- Новые события для отслеживания игр ---
    event GameRequested(uint256 indexed requestId, address indexed player, uint8 playerChoice, uint256 bet); // Событие при отправке ставки
    event GameFinished(uint256 indexed requestId, address indexed player, uint8 playerChoice, uint8 casinoChoice, string result, uint256 payout); // Событие при получении результата

    // Маппинг для отслеживания ставок по ID запроса
    struct PendingGame {
        address player;
        uint256 bet;
        uint8 playerChoice;
    }
    mapping(uint256 => PendingGame) private s_requests;

    // Структура для хранения информации о последней игре
    struct LastGame {
        address player;        // кто играл
        uint8 playerChoice;    // выбор игрока (0-камень, 1-ножницы, 2-бумага)
        uint8 randomNumber;    // выбор контракта
        string result;         // результат (Win/Lose/Draw)
        uint256 bet;           // размер ставки
    }

    // Хранит информацию о последнем раунде
    LastGame public lastRound;

    // Конструктор
    // При деплое сохраняем владельца через конструктор родителя
    constructor(uint256 subscriptionId) VRFConsumerBaseV2Plus(vrfCoordinator) payable {
        // Мы не объявляем owner здесь, Chainlink сам назначит msg.sender владельцем
        s_subscriptionId = subscriptionId;
    }

    // Модификатор onlyOwner уже определен в родительском контракте, 
    // нам не нужно его писать заново.

    // Информационная функция
    // Возвращает правила игры
    function getRules() external pure returns (string memory) {
        return unicode"Правила: 0-Камень, 1-Ножницы, 2-Бумага. Выигрыш: x2 от ставки. Ничья: возврат. Рандом через Chainlink VRF v2.5.";
    }

    // Публичные функции игры
    function playRock() external payable nonReentrant { _play(0); } // Добавлен nonReentrant
    function playScissors() external payable nonReentrant { _play(1); } // Добавлен nonReentrant
    function playPaper() external payable nonReentrant { _play(2); } // Добавлен nonReentrant

    // Внутренняя логика игры
    function _play(uint8 _playerChoice) internal {
        require(msg.value >= MIN_BET, "Bet too low");
        require(address(this).balance >= msg.value * 2, "Contract is empty");

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) 
                )
            })
        );

        s_requests[requestId] = PendingGame({
            player: msg.sender,
            bet: msg.value,
            playerChoice: _playerChoice
        });

        emit GameRequested(requestId, msg.sender, _playerChoice, msg.value); // Логирование запроса рандома
    }

    // Колбэк от Chainlink
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        PendingGame memory game = s_requests[requestId];
        if (game.player == address(0)) return; // Проверка на существование запроса

        uint8 randomNumber = uint8(randomWords[0] % 3);
        string memory gameResult;
        uint256 payout = 0;

        if (game.playerChoice == randomNumber) {
            gameResult = "Draw";
            payout = game.bet;
        } 
        else if (
            (game.playerChoice == 0 && randomNumber == 1) || 
            (game.playerChoice == 1 && randomNumber == 2) || 
            (game.playerChoice == 2 && randomNumber == 0)
        ) {
            gameResult = "You Win!";
            payout = game.bet * 2;
        } 
        else {
            gameResult = "Lose";
        }

        lastRound = LastGame({
            player: game.player,
            playerChoice: game.playerChoice,
            randomNumber: randomNumber,
            result: gameResult,
            bet: game.bet
        });

        emit GameFinished(requestId, game.player, game.playerChoice, randomNumber, gameResult, payout); // Логирование результата игры

        if (payout > 0) {
            (bool success, ) = payable(game.player).call{value: payout}(""); // Заменено на .call для безопасности
            require(success, "Transfer failed"); // Проверка успешности транзакции
        }

        delete s_requests[requestId];
    }

    // Пополнение контракта
    function deposit() external payable {}

    // Вывод средств владельцем
    // Используем встроенный модификатор onlyOwner
    function withdrawAll() external onlyOwner nonReentrant { // Добавлен nonReentrant
        uint256 amount = address(this).balance; // Сохраняем баланс перед выводом
        (bool success, ) = payable(msg.sender).call{value: amount}(""); // Заменено на .call
        require(success, "Withdrawal failed"); // Проверка успешности вывода
    }

    // Просмотр баланса контракта
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}