// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {IERC721CreatorCore} from "manifoldxyz/creator-core/core/IERC721CreatorCore.sol";
import {ICreatorExtensionTokenURI} from
    "manifoldxyz/creator-core/extensions/ICreatorExtensionTokenURI.sol";
import {IERC721CreatorExtensionApproveTransfer} from
    "manifoldxyz/creator-core/extensions/ERC721/IERC721CreatorExtensionApproveTransfer.sol";
import {ERC165Checker} from "openzeppelin/utils/introspection/ERC165Checker.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IERC165} from "openzeppelin/utils/introspection/IERC165.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract DynamicTokenURI is
    Ownable,
    ICreatorExtensionTokenURI,
    IERC721CreatorExtensionApproveTransfer
{
    // Cost to mint a token
    uint256 public immutable mintCost;
    // Total supply of tokens meant to be minted with this extension
    uint256 public immutable maxSupply;
    // Manifold creator contract
    IERC721CreatorCore public immutable creatorContract;

    // Amount of tokens currently minted with this extension
    uint256 public minted;
    // Base URI for token URIs
    string public baseURI;
    mapping(uint256 => uint256) private tokenIdToMetadataId;

    constructor(
        address creatorContract_,
        string memory baseURI_,
        uint256 maxSupply_,
        uint256 mintCost_
    ) Ownable() {
        require(
            ERC165Checker.supportsInterface(creatorContract_, type(IERC721CreatorCore).interfaceId),
            "creator must implement IERC721CreatorCore"
        );
        require(bytes(baseURI_).length != 0, "baseURI must not be empty");
        require(maxSupply_ != 0, "maxSupply must be positive");

        creatorContract = IERC721CreatorCore(creatorContract_);
        baseURI = baseURI_;
        maxSupply = maxSupply_;
        mintCost = mintCost_;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(bytes(baseURI_).length != 0, "baseURI must not be empty");
        baseURI = baseURI_;
    }

    /// @notice Disable the transfer callback if needed
    function setApproveTransfer(address creatorContract_, bool enabled_) external onlyOwner {
        require(creatorContract_ == address(creatorContract), "invalid creator");
        IERC721CreatorCore(creatorContract_).setApproveTransferExtension(enabled_);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(ICreatorExtensionTokenURI).interfaceId
            || interfaceId == type(IERC721CreatorExtensionApproveTransfer).interfaceId;
    }

    function tokenURI(address, /* creatorContract */ uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        uint256 metadataId = _getMetadataId(tokenId);
        // This assumes the following directory structure in baseURI:
        // .
        // └──<baseURI>
        //    ├── 1.json
        //    ├── 2.json
        //    ├── ...
        //    └── <maxChanges>.json
        return string(abi.encodePacked(baseURI, Strings.toString(metadataId), ".json"));
    }

    function _getMetadataId(uint256 tokenId) internal view returns (uint256) {
        uint256 metadataId = tokenIdToMetadataId[tokenId];
        if (metadataId == 0) {
            return 1;
        }
        // If within the change limit, use the metadata id.
        // Otherwise, use maxSupply, iow., the artwork will
        // frieze to the last artwork after the token shifts
        // through the whole supply.
        return maxSupply > metadataId ? metadataId : maxSupply;
    }

    /**
     * @dev Called by creator contract to approve a transfer
     */
    function approveTransfer(address, /* operator */ address from, address to, uint256 tokenId)
        external
        returns (bool)
    {
        require(msg.sender == address(creatorContract), "invalid caller");
        if (from == address(0) || to == address(0)) {
            // This is a mint or a burn, do nothing
            return true;
        }

        uint256 metadataId = _getMetadataId(tokenId);
        // No more token URI changes once the max number of changes is reached
        if (metadataId >= maxSupply) {
            return true;
        }

        unchecked {
            // realistically never overflows
            ++metadataId;
        }
        tokenIdToMetadataId[tokenId] = metadataId;

        return true;
    }

    function mint() external payable returns (uint256) {
        require(msg.value == mintCost, "insufficient funds");
        uint256 tokensMinted = minted;
        require(tokensMinted < maxSupply, "mint complete");

        // Transfer mint cost to owner
        if (msg.value != 0) {
            (bool success,) = owner().call{value: msg.value}("");
            require(success, "transfer failed");
        }

        // Mint a token to the caller
        unchecked {
            // realistically never overflows
            ++tokensMinted;
        }
        minted = tokensMinted;
        return IERC721CreatorCore(creatorContract).mintExtension(msg.sender);
    }
}
