// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";

contract Tauri is Erc721("Tauri", "TNFT") {

    function tokenURI(
        uint256 id
    ) public view virtual override returns(string memory) {
        return "base-marketplace";
    }

    function mint(
        address receiver, 
        uint256 tokenId
    ) public payable {
        _mint(receiver, tokenId);
    }
}