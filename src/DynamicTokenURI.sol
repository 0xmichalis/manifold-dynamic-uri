// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {IERC721CreatorCore} from "manifoldxyz/creator-core/core/IERC721CreatorCore.sol";
import {ICreatorExtensionTokenURI} from "manifoldxyz/creator-core/extensions/ICreatorExtensionTokenURI.sol";
import {IERC721CreatorExtensionApproveTransfer} from
    "manifoldxyz/creator-core/extensions/ERC721/IERC721CreatorExtensionApproveTransfer.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC165} from "openzeppelin/utils/introspection/ERC165.sol";
import {ERC165Checker} from "openzeppelin/utils/introspection/ERC165Checker.sol";

contract DynamicTokenURI is Ownable, ICreatorExtensionTokenURI, IERC721CreatorExtensionApproveTransfer {
    constructor() Ownable(msg.sender) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(Ownable).interfaceId || interfaceId == type(ICreatorExtensionTokenURI).interfaceId
            || interfaceId == type(IERC721CreatorExtensionApproveTransfer).interfaceId;
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

    /**
     * @dev Set whether or not the creator will check the extension for approval of token transfer
     */
    function setApproveTransfer(address creator, bool enabled) external {
        require(
            ERC165Checker.supportsInterface(creator, type(IERC721CreatorCore).interfaceId),
            "creator must implement IERC721CreatorCore"
        );
        IERC721CreatorCore(creator).setApproveTransferExtension(enabled);
    }

    /**
     * @dev Called by creator contract to approve a transfer
     */
    function approveTransfer(address operator, address from, address to, uint256 tokenId) external returns (bool) {
        return true;
    }
}
