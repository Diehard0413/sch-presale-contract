// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./tokens/ERC20.sol";

contract SCH is ERC20 {
    // constructor() ERC20(unicode"SCHÖPF", unicode"SCH$") {
    //     _mint(msg.sender, 12000000 * 10 ** decimals());
    // }

    constructor() ERC20("SCH", "SCH") {
        _mint(msg.sender, 12000000 * 10 ** decimals());
    }
}