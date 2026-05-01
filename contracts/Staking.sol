// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}
contract Staking {
    IERC20 public immutable token;

    struct Stake {
        uint256 amount;        // Сумма стейка
        uint256 timestamp;     // Время последнего обновления
        uint256 unclaimed;     // Накопленные, но не выплаченные награды
    }

    mapping(address => Stake) public stakes;
    uint256 public constant rewardRate = 10; // 10% годовых

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    constructor(address _token) {
        token = IERC20(_token);
    }

    // Внутренняя функция для фиксации накопленных наград перед любым изменением баланса
    function _updateRewards(address user) internal {
        Stake storage s = stakes[user];
        if (s.amount > 0) {
            s.unclaimed += _calculateNewRewards(user);
        }
        s.timestamp = block.timestamp;
    }

    // Расчет наград, накопленных С МОМЕНТА последнего обновления
    function _calculateNewRewards(address user) internal view returns (uint256) {
        Stake storage s = stakes[user];
        uint256 timePassed = block.timestamp - s.timestamp;
        // (Баланс * Процент * Время) / (Секунд в году * 100)
        return (s.amount * rewardRate * timePassed) / (365 days * 100);
    }

    // Публичная функция для просмотра общей доступной награды
    function calculateReward(address user) public view returns (uint256) {
        Stake storage s = stakes[user];
        return s.unclaimed + _calculateNewRewards(user);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        
        // Сначала сохраняем старые награды, чтобы они не обнулились
        _updateRewards(msg.sender);

        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        stakes[msg.sender].amount += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake() external {
        Stake storage s = stakes[msg.sender];
        require(s.amount > 0, "Nothing to unstake");

        // Считаем общую награду
        uint256 reward = calculateReward(msg.sender);
        uint256 principal = s.amount;

        // Обнуляем данные пользователя перед отправкой (защита от Reentrancy)
        s.amount = 0;
        s.unclaimed = 0;
        s.timestamp = block.timestamp;

        // Отправляем тело стейка + награду
        // Важно: на контракте должны быть токены для выплаты наград!
        require(token.transfer(msg.sender, principal + reward), "Transfer failed");

        emit Unstaked(msg.sender, principal, reward);
    }
}