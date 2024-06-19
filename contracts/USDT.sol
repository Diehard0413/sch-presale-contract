// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./tokens/ERC20T.sol";

contract USDT is ERC20T {
    constructor() ERC20T("USDT", "USDT") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }
}