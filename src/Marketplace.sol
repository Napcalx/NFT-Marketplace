// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import { SignUtils } from "./libraries/SignUtils.sol";

contract Marketplace {
    struct Order {
        address token;
        uint256 tokenId;
        uint256 price;
        bytes sig;

        uint88 deadline;
        address seller;
        bool active;
    }

    mapping(uint256 => Order) public orders;
    address public admin;
    uint256 public orderId;

    // Errors
    error NotOwner();
    error NotApproved();
    error MinPriceTooLow();
    error DeadlineTooSoon();
    error MinDurationNotMet();
    error InvalidSignature();
    error OrderNotExisting();
    error OrderNotActive();
    error PriceNotMet(int256 difference);
    error OrderExpired();
    error PriceMisMatch(uint256 originalPrice);

    //Events
    event OrderCreated(uint256 indexed orderId, Order);
    event OrderFulfilled(uint256 indexed orderId, Order);
    event OrderEdited(uint256 indexed orderId, Order);

    constructor () {
        admin = msg.sender;
    }

    function createOrder(Order calldata O) public returns (uint256 OId) {
        if(ERC721(O.token).ownerOf(O.tokenId) != msg.sender) revert NotOwner();
        if(!ERC721(O.token).isApprovedForAll(msg.sender, address(this))) revert NotApproved();
        if(O.price < 0.01 ether) revert MinPriceTooLow();
        if(O.deadline < block.timestamp) revert DeadlineTooSoon();
        if(O.deadline - block.timestamp < 60 minutes) revert MinDurationNotMet();

        if (
            !SignUtils.isValid (
                SignUtils.constructMessageHash (
                    O.token,
                    O.tokenId,
                    O.price,
                    O.deadline,
                    O.seller
                ),
                O.sig,
                msg.sender
            )
        ) revert InvalidSignature();

        Order storage Od = orders[orderId];
        Od.token = O.token;
        Od.tokenId = O.tokenId;
        Od.price = O.price;
        Od.sig = O.sig;
        Od.deadline = uint88(O.deadline);
        Od.seller = msg.sender;
        Od.active = true;

        emit OrderCreated(orderId, O);
        OId = orderId;
        orderId++;
        return OId;
    }

    function executeOrder(uint256 _orderId) public payable {
        if(_orderId >= orderId) revert OrderNotExisting();
        Order storage order = orders[_orderId];
        if(order.deadline < block.timestamp) revert OrderExpired();
        if(!order.active) revert OrderNotActive();
        if(order.price < msg.value) revert PriceMisMatch(order.price);
        if(order.price != msg.value) revert PriceNotMet(int256(order.price) - int256(msg.value));

        order.active = false;

        ERC721(order.token).transferFrom(
            order.seller,
            msg.sender,
            order.tokenId
        );

        payable(order.seller).transfer(order.price);

        emit OrderFulfilled(_orderId, order);
    }

    function editOrder(
        uint256 _orderId, 
        uint256 _newPrice,
        bool _active
    ) public {
        if(_orderId >= orderId) revert OrderNotExisting();
        Order storage order = orders[_orderId];
        if(order.seller != msg.sender) revert NotOwner();
        order.active = _active;
        order.price = _newPrice;
        emit OrderEdited(_orderId, order);
    }

    function getOrder(
        uint256 _orderId
    ) public view returns (Order memory) {
        return orders[_orderId];
    }
}