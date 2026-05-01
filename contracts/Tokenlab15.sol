// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20{
    constructor() ERC20("Digital Altyn V2","dAuV2"){
        _mint(msg.sender, 10000000*10**18); // 10000000 dAuV2
    }
}