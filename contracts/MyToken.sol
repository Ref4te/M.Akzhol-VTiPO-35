// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20{
    constructor() ERC20("Manat Staking Token","MST"){
        _mint(msg.sender, 1000000*10**18); // 100000 MST
    }
}