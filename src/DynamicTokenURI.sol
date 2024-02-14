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

struct ExtensionConfig {
    // Cost to mint a token
    uint256 mintCost;
    // Max supply of tokens to be minted by this extension
    uint256 maxSupply;
    // Base URI for token URIs minted by this extension
    string baseURI;
}

contract DynamicTokenURI is
    Ownable,
    ICreatorExtensionTokenURI,
    IERC721CreatorExtensionApproveTransfer
{
    // Mapping from creator contracts to extension configs
    mapping(address => ExtensionConfig) public extensionConfigs;
    // Mapping from creator contracts to amount of tokens currently
    // minted with this extension
    mapping(address => uint256) public creatorsToMinted;
    // Mapping from creator contracts to token ID to metadata ID.
    // The metadata ID keeps track of the metadata file to use for
    // a given token ID. Tokens that have never been transferred
    // start with a metadata ID of 1, then every time a token is
    // transferred, the metadata ID is incremented by 1, all the
    // way up to maxSupply.
    mapping(address => mapping(uint256 => uint256)) private _creatorsToTokenIdToMetadataId;
    // Mapping from creator contracts to metadata ID to metadata string
    // Can be used to avoid the assumption that every metadata file is
    // named after a number.
    mapping(address => mapping(uint256 => string)) public metadataStrings;

    constructor() Ownable() {}

    function setExtensionConfig(
        address creatorContract,
        string memory baseURI,
        uint256 maxSupply,
        uint256 mintCost
    ) external onlyOwner {
        require(
            ERC165Checker.supportsInterface(creatorContract, type(IERC721CreatorCore).interfaceId),
            "creator must implement IERC721CreatorCore"
        );
        require(bytes(baseURI).length != 0, "baseURI must not be empty");
        require(maxSupply != 0, "maxSupply must be positive");

        ExtensionConfig memory config =
            ExtensionConfig({baseURI: baseURI, maxSupply: maxSupply, mintCost: mintCost});
        extensionConfigs[creatorContract] = config;
    }

    /// @notice Set token URIs for a range of metadata IDs
    /// This can be used to avoid the assumption that every metadata file is
    /// named after a number.
    /// @param creatorContract The creator contract
    /// @param metadataIds The metadata IDs
    /// @param tokenURIs The token URIs
    function setTokenURIs(
        address creatorContract,
        uint256[] memory metadataIds,
        string[] memory tokenURIs
    ) external onlyOwner {
        require(
            ERC165Checker.supportsInterface(creatorContract, type(IERC721CreatorCore).interfaceId),
            "creator must implement IERC721CreatorCore"
        );
        uint256 metadataLen = metadataIds.length;
        require(metadataLen == tokenURIs.length, "length mismatch");
        for (uint256 i; i < metadataLen; ++i) {
            metadataStrings[creatorContract][metadataIds[i]] = tokenURIs[i];
        }
    }

    /// @notice Disable the transfer callback if needed
    function setApproveTransfer(address creatorContract, bool enabled) external onlyOwner {
        require(
            ERC165Checker.supportsInterface(creatorContract, type(IERC721CreatorCore).interfaceId),
            "creator must implement IERC721CreatorCore"
        );
        IERC721CreatorCore(creatorContract).setApproveTransferExtension(enabled);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(ICreatorExtensionTokenURI).interfaceId
            || interfaceId == type(IERC721CreatorExtensionApproveTransfer).interfaceId;
    }

    function tokenURI(address creatorContract, uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        uint256 metadataId = _getMetadataId(creatorContract, tokenId);

        // The assumption below can be avoided by using the metadataStrings mapping
        string memory uri = metadataStrings[creatorContract][metadataId];
        if (bytes(uri).length != 0) {
            return uri;
        }

        string memory baseURI = extensionConfigs[creatorContract].baseURI;
        // This assumes the following directory structure in baseURI:
        // .
        // └──<baseURI>
        //    ├── 1.json
        //    ├── 2.json
        //    ├── ...
        //    └── <maxSupply>.json
        return string(abi.encodePacked(baseURI, Strings.toString(metadataId), ".json"));
    }

    function _getMetadataId(address creatorContract, uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        uint256 maxSupply = extensionConfigs[creatorContract].maxSupply;
        require(maxSupply != 0, "extension not configured");

        uint256 metadataId = _creatorsToTokenIdToMetadataId[creatorContract][tokenId];
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
        uint256 maxSupply = extensionConfigs[msg.sender].maxSupply;
        require(maxSupply != 0, "extension not configured");

        if (from == address(0) || to == address(0)) {
            // This is a mint or a burn, do nothing
            return true;
        }

        uint256 metadataId = _getMetadataId(msg.sender, tokenId);
        // No more token URI changes once the max number of changes is reached
        if (metadataId >= maxSupply) {
            return true;
        }

        unchecked {
            // realistically never overflows
            ++metadataId;
        }
        _creatorsToTokenIdToMetadataId[msg.sender][tokenId] = metadataId;

        return true;
    }

    function mint(address creatorContract) external payable returns (uint256) {
        uint256 maxSupply = extensionConfigs[creatorContract].maxSupply;
        require(maxSupply != 0, "extension not configured");

        uint256 mintCost = extensionConfigs[creatorContract].mintCost;
        require(msg.value == mintCost, "insufficient or too many funds");

        uint256 tokensMinted = creatorsToMinted[creatorContract];
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
        creatorsToMinted[creatorContract] = tokensMinted;
        return IERC721CreatorCore(creatorContract).mintExtension(msg.sender);
    }
}
