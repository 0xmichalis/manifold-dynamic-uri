// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./DynamicTokenURI.sol";

contract DynamicTokenURI24 is DynamicTokenURI {
    constructor(address creatorContract_, string memory baseURI_)
        DynamicTokenURI(creatorContract_, baseURI_, 24, 0.001 ether)
    {}
}
