// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Marketplace} from "../src/Marketplace.sol";
import "../src/ERC721Mock.sol";
import "./Helpers.sol";

contract MarketPlaceTest is Helpers {
    Marketplace mPlace;
    Tauri nft;

    uint256 currentOrderId;

    address user1;
    address user2;

    uint256 privKey1;
    uint256 privKey2;
    
    Marketplace.Order O;

    function setUp() public {
        mPlace = newMarketplace();
        nft = new Tauri();

        (user1, privKey1) = makeaddr("USER1");
        (user2, privKey2) = makeaddr("USER2");

        O = Marketplace.Order({
            token: address(nft),
            tokenId: 1,
            price: 1 ether,
            sig: bytes(""),
            deadline: 0,
            seller: address(0),
            active: false
        });
        nft.mint(user1, 1);
    }

    function testOwnerCannotCreateOrder() public {
        O.seller = user2;
        switchSigner(user2);

        vm.expectRevert(Marketplace.NotOwner.selector);
        mPlace.createOrder(1);
    }

    function testNonApprovedNFT() public {
        switchSigner(user1);
        vm.expectRevert(Marketplace.NotApproved.selector);
        mPlace.createOrder(1);
    }

    function testMinPriceTooLow() public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.price = 0;
        vm.expectRevert(Marketplace.MinPriceTooLow.selector);
        mPlace.createOrder(1);
    }

    function testMinDeadline() public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(deadline > block.timestamp);
        vm.expectRevert(Marketplace.MinDeadline.selector);
        mPlace.createOrder(1);
    }

    function testMinDuration() public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(Marketplace.MinDuration.selector);
        mPlace.createOrder(1);
    }

    function testValidSig() public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 120 minutes);
        O.sig = constructSig(
            O.token,
            O.tokenId,
            O.price,
            O.deadline,
            O.seller,
            privKey2
        );
        vm.expectRevert(Marketplace.InvalidSignature.selector);
        mPlace.createOrder(l);
    }

    function testEditNonValidOrder() public {
        switchSigner(user1);
        vm.expectRevert(Marketplace.OrderNotExisting.selector);
        mPlace.editOrder(1, 0, false);
    }

    function testEditOrderNotOwner() public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 120 minutes);
        O.sig = constructSig(
            O.token,
            O.tokenId,
            O.price,
            O.deadline,
            O.lister,
            privKey1
        );
        uint256 OId = mPlace.createOrder(l);

        switchSigner(user2);
        vm.expectRevert(Marketplace.NotOwner.selector);
        mPlace.editOrder(OId, 0, false);
    }

    function testEditOrder() public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 120 minutes);
        O.sig = constructSig(
            O.token,
            O.tokenId,
            O.price,
            O.deadline,
            O.seller,
            privKey1
        );
        uint256 OId = mPlace.createOrder(l);
        mPlace.editOrder(OId, 0.01 ether, false);

        Marketplace.Order memory k = mPlace.getOrder(OId);
        assertEq(k.price, 0.01 ether);
        assertEq(k.active, false);
    }

    function testExecuteNonValidOrder() public {
        switchSigner(user1);
        vm.expectRevert(Marketplace.OrderNotExisting.selector);
        mPlace.executeOrder(1);
    }

    function testExecuteExpiredOrder() public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
    }

    function testExecuteOrderNotActive () public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 120 minutes);
        O.sig = constructSig(
            O.token,
            O.tokenId,
            O.price,
            O.deadline,
            O.seller,
            privKey1
        );
        uint256 OId = mPlace.createOrder(l);
        mPlace.editOrder(OId, 0.01 ether, false);
        switchSigner(user2);
        vm.expectRevert(Marketplace.OrderNotActive.selector);
        mPlace.executeOrder(OId);
    }

    function testExecutePriceNotMet () public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 120 minutes);
        O.sig = constructSig(
            O.token,
            O.tokenId,
            O.price,
            O.deadline,
            O.seller,
            privKey1
        );
        uint256 OId = mPlace.createOrder(l);
        switchSigner(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.PriceNotMet.selector,
                O.price - 0.9 ether
            )
        );
        mPlace.executeOrder{value: 0.9 ether}(OId);
    }

    function testExecutePriceMistMatch () public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 120 minutes);
        O.sig = constructSig(
            O.token,
            O.tokenId,
            O.price,
            O.deadline,
            O.seller,
            privKey1
        );
        uint256 OId = mPlace.createOrder(l);
        switchSigner(user2);
        vm.expectRevert(
            abi.encodeWithSelector(Marketplace.PriceMisMatch.selector, O.price)
        );
        mPlace.executeOrder{value: 1.1 ether}(OId);
    }

    function testExecute () public {
        switchSigner(user1);
        nft.setApprovalForAll(address(mPlace), true);
        O.deadline = uint88(block.timestamp + 120 minutes);
        O.sig = constructSig(
            O.token,
            O.tokenId,
            O.price,
            O.deadline,
            O.seller,
            privKey1
        );
        uint256 OId = mPlace.createOrder(l);
        switchSigner(user2);
        uint256 user1BalanceBefore = user1.balance;

        mPlace.executeOrder{value: l.price}(OId);

        uint256 user1BalanceAfter = user1.balance;

        Marketplace.Order memory k = mPlace.getOrder(OId);
        assertEq(k.price, 1 ether);
        assertEq(k.active, false);

        assertEq(t.active, false);
        assertEq(ERC721(O.token).ownerOf(O.tokenId), user2);
        assertEq(user1BalanceAfter, user1BalanceBefore + O.price);
    }
}
