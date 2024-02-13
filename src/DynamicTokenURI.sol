// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {IERC721CreatorCore} from "manifoldxyz/creator-core/core/IERC721CreatorCore.sol";
import {ICreatorExtensionTokenURI} from
    "manifoldxyz/creator-core/extensions/ICreatorExtensionTokenURI.sol";
import {IERC721CreatorExtensionApproveTransfer} from
    "manifoldxyz/creator-core/extensions/ERC721/IERC721CreatorExtensionApproveTransfer.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC165} from "openzeppelin/utils/introspection/ERC165.sol";
import {ERC165Checker} from "openzeppelin/utils/introspection/ERC165Checker.sol";

contract DynamicTokenURI is ICreatorExtensionTokenURI, IERC721CreatorExtensionApproveTransfer {
    // Immutable storage
    uint256 public immutable maxChanges;

    // Mutable storage
    string public baseURI;
    mapping(uint256 => uint256) private tokenIdToMetadataId;

    constructor(string memory baseURI_, uint256 maxChanges_) {
        require(bytes(baseURI_).length != 0, "baseURI must not be empty");
        require(maxChanges_ != 0, "maxChanges must be positive");
        baseURI = baseURI_;
        maxChanges = maxChanges_;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(ICreatorExtensionTokenURI).interfaceId
            || interfaceId == type(IERC721CreatorExtensionApproveTransfer).interfaceId;
    }

    function tokenURI(address, /* creator */ uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        // This assumes the following directory structure in baseURI:
        // .
        // └──<baseURI>
        //    ├── 1.json
        //    ├── 2.json
        //    ├── ...
        //    └── <maxChanges>.json
        return string(abi.encodePacked(baseURI, _getMetadataId(tokenId), ".json"));
    }

    function _getMetadataId(uint256 tokenId) internal view returns (uint256) {
        uint256 metadataId = tokenIdToMetadataId[tokenId];
        if (metadataId == 0) {
            return 1;
        }
        // If within the change limit, use the metadata id.
        // Otherwise, use maxChanges, iow., the artwork will stop
        // shifting after the max number of changes is reached and
        // will stay with the final artwork forever.
        return maxChanges > metadataId ? metadataId : maxChanges;
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
    function approveTransfer(address, /* operator */ address from, address to, uint256 tokenId)
        external
        returns (bool)
    {
        if (from == address(0) || to == address(0)) {
            // This is a mint or a burn, do nothing
            return true;
        }

        uint256 metadataId = _getMetadataId(tokenId);
        // No more token URI changes once the max number of changes is reached
        if (metadataId >= maxChanges) {
            return true;
        }

        unchecked {
            // realistically never overflows
            ++metadataId;
        }
        tokenIdToMetadataId[tokenId] = metadataId;

        return true;
    }
}
