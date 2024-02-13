//SPDX-License-Identifier: Anti-996 License
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {ERC721Creator} from "manifoldxyz/creator-core/ERC721Creator.sol";
import {ICreatorExtensionTokenURI} from
    "manifoldxyz/creator-core/extensions/ICreatorExtensionTokenURI.sol";
import {IERC721CreatorExtensionApproveTransfer} from
    "manifoldxyz/creator-core/extensions/ERC721/IERC721CreatorExtensionApproveTransfer.sol";
import {ERC165Checker} from "openzeppelin/utils/introspection/ERC165Checker.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

import {DynamicTokenURI} from "../src/DynamicTokenURI.sol";

contract DynamicTokenURITest is Test {
    // users
    address creator = address(0xC12EA7012);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    // contracts
    ERC721Creator private token;
    DynamicTokenURI private extension;

    // data
    string baseURI = "ipfs://ipfs/examplevhbgbfjdg/";
    uint256 maxSupply = 24;
    uint256 mintCost = 0.1 ether;

    function setUp() public {
        // Deploy the creator contract
        vm.prank(creator);
        token = new ERC721Creator("OONA", "OONA42069");

        // Deploy the extension contract
        vm.prank(creator);
        extension = new DynamicTokenURI(address(token), baseURI, maxSupply, mintCost);

        // Register the extension in the creator contract
        vm.prank(creator);
        token.registerExtension(address(extension), "");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testSupportsInterface() public view {
        assert(
            ERC165Checker.supportsInterface(
                address(extension), type(ICreatorExtensionTokenURI).interfaceId
            )
        );
        assert(
            ERC165Checker.supportsInterface(
                address(extension), type(IERC721CreatorExtensionApproveTransfer).interfaceId
            )
        );
    }

    function testSimpleMintAndTransfer() public {
        uint256 balanceBefore = address(creator).balance;

        // 1. Alice mints a token
        vm.prank(alice);
        uint256 tokenId = extension.mint{value: mintCost}();
        string memory aliceURI = token.tokenURI(tokenId);
        string memory expectedAliceURI = string(abi.encodePacked(baseURI, "1.json"));
        assertEq(aliceURI, expectedAliceURI);

        // Check owner balance
        uint256 balanceAfter = address(creator).balance;
        assertEq(balanceAfter - balanceBefore, mintCost);

        // 2. Alice transfers the token to Bob. The URI should change
        vm.prank(alice);
        token.transferFrom(alice, bob, tokenId);
        string memory bobURI = token.tokenURI(tokenId);
        string memory expectedBobURI = string(abi.encodePacked(baseURI, "2.json"));
        assertEq(bobURI, expectedBobURI);
    }

    function testTransferUpToMaxChange() public {
        // 1. Alice mints a token
        vm.prank(alice);
        uint256 tokenId = extension.mint{value: mintCost}();

        // 2. Token URI changes up to maxSupply
        address owner = alice;
        address recipient = bob;
        string memory lastURI;
        for (uint256 i = 0; i < maxSupply - 1; i++) {
            // Transfer from owner to recipient
            vm.prank(owner);
            token.transferFrom(owner, recipient, tokenId);

            // Check URI
            string memory expectedURI =
                string(abi.encodePacked(baseURI, Strings.toString(i + 2), ".json"));
            string memory uri = token.tokenURI(tokenId);
            assertEq(uri, expectedURI);

            // Update stuff
            owner = owner == alice ? bob : alice;
            recipient = recipient == alice ? bob : alice;
            lastURI = uri;
        }

        // 3. Token URI should not change after maxSupply
        vm.prank(owner);
        token.transferFrom(owner, recipient, tokenId);
        string memory finalURI = token.tokenURI(tokenId);
        string memory expectedFinalURI =
            string(abi.encodePacked(baseURI, Strings.toString(maxSupply), ".json"));
        assertEq(finalURI, expectedFinalURI);
        assertEq(finalURI, lastURI);
    }

    function testInvalidCallerToTransferCallback() public {
        // Token contract can call the callback
        vm.prank(address(token));
        extension.approveTransfer(address(0), alice, bob, 1);

        // Others cannot
        vm.prank(alice);
        vm.expectRevert("invalid caller");
        extension.approveTransfer(address(0), alice, bob, 1);
    }

    function testCannotCallSetApproveTransfer() public {
        // Creator can call the callback
        vm.prank(creator);
        extension.setApproveTransfer(address(token), false);

        // Others cannot
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        extension.setApproveTransfer(address(token), false);
    }

    function testCannotCallSetBaseURI() public {
        // Creator can call the callback
        vm.prank(creator);
        extension.setBaseURI("testURI");

        // Others cannot
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        extension.setBaseURI("testURI");
    }

    function testCannotMintMoreThanMaxSupply() public {
        uint256 balanceBefore = address(creator).balance;

        // Mint up to maxSupply
        for (uint256 i = 0; i < maxSupply; i++) {
            vm.prank(alice);
            extension.mint{value: mintCost}();
        }
        assertEq(token.balanceOf(alice), maxSupply);

        // Check owner balance
        uint256 balanceAfter = address(creator).balance;
        assertEq(balanceAfter - balanceBefore, mintCost * maxSupply);

        // Cannot mint more
        vm.prank(alice);
        vm.expectRevert("mint complete");
        extension.mint{value: mintCost}();
    }
}
