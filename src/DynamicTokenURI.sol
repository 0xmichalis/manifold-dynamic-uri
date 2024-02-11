// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {ICreatorExtensionTokenURI} from "manifoldxyz/creator-core/extensions/ICreatorExtensionTokenURI.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC165} from "openzeppelin/utils/introspection/ERC165.sol";

contract DynamicTokenURI is ICreatorExtensionTokenURI {
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(ICreatorExtensionTokenURI).interfaceId;
    }

    function tokenURI(address creator, uint256 tokenId) external view override returns (string memory) {
        address tokenOwner = IERC721(creator).ownerOf(tokenId);
        // TODO: What should be shown if the work is burned?
        require(tokenOwner != address(0), "Invalid token");

        uint256 addressNumber = uint256(uint160(tokenOwner));
        // TODO: This should be read from the creator contract
        uint256 totalNumberOfArtworks = 69;
        // Naive way to rotate artworks for a token while the token
        // is transferred between owners.
        uint256 metadataId = (addressNumber % totalNumberOfArtworks) + 1;

        // This assumes the following directory structure in IPFS:
        // .
        // └──<ipfs_directory>
        //    ├── 1.json
        //    ├── 2.json
        //    ├── ...
        //    └── <totalNumberOfArtworks>.json
        //
        // TODO: Read the IPFS directory from the creator contract
        // or allow setting it in this contract
        return string(abi.encodePacked("ipfs://<ipfs_directory>/", metadataId, ".json"));
    }
}
