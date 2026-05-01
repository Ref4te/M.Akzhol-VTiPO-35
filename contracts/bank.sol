// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GiftBank {
    // 1. Создайте mapping: address -> uint256 (баланс пользователя)
    // Ваш код ↓
    mapping(address=>uint256) public balance;

    // 2. Создайте событие BigDeposit(address indexed user, uint256 amount)
    // Ваш код ↓
    event BigDeposit(address indexed user, uint256 amount);


    // 3. Модификатор: проверка, что баланс пользователя > 0
    // Ваш код ↓
    modifier checkBalance(){
        require(balance[msg.sender]>0,"Balance must be > 0");
        _;
    }

    // 4. Функция deposit() - пополнение баланса
    // - требует amount > 0
    // - обновляет mapping
    // - если amount > 1 ether -> 
    //   а) Emit BigDeposit событие
    //   б) Добавить 0.01 ether подарка к balance
    // Ваш код ↓
    function deposit() external payable {
        require(msg.value>0,"Amount must be > 0");
        balance[msg.sender] += msg.value;
        if(msg.value>1 ether){
            emit BigDeposit(msg.sender,msg.value);
            balance[msg.sender] += 0.01 ether;
        }
    }

    // 5. Функция withdraw(uint256 amount) - снятие
    // - требует balance[msg.sender] >= amount
    // - уменьшает баланс
    // - отправляет эфир пользователю
    // Ваш код ↓
    function withdraw(uint256 amount) external{
        require(checkBalance, "Balance is empty");
        require((balance[msg.sender]>=amount),"Balance must be >= amount");
        balance.msg.sender -= amount;
        payable msg.sender.transfer(amount);
    }
}