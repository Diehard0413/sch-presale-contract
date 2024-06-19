// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC165.sol";
import "../utils/Initializable.sol";

abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}