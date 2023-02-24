// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ISecondaryMarket.sol";
import "../interfaces/IPrimaryMarket.sol";
import "../interfaces/ITicketNFT.sol";
import "../interfaces/IERC20.sol";

contract SecondaryMarket is ISecondaryMarket {
    struct TicketListingInfo {
        uint256 price;
        address seller;
    }

    uint256 public constant FEE_PERCENT = 5;

    ITicketNFT public ticketNFT;
    IERC20 public purchaseToken;
    IPrimaryMarket public primaryMarket;

    mapping(uint256 => TicketListingInfo) public ticketListings;

    modifier isValidTicket(uint256 ticketID) {
        require(
            !ticketNFT.isExpiredOrUsed(ticketID),
            "Ticket is invalid - has expired or been used"
        );
        _;
    }

    modifier isListedTicket(uint256 ticketID) {
        require(ticketListings[ticketID].price > 0, "Ticket is not listed");
        _;
    }

    constructor(
        ITicketNFT ticketNFT_,
        IERC20 purchaseToken_,
        IPrimaryMarket primaryMarket_
    ) {
        ticketNFT = ticketNFT_;
        purchaseToken = purchaseToken_;
        primaryMarket = primaryMarket_;
    }

    function listTicket(uint256 ticketID, uint256 price)
        external
        isValidTicket(ticketID)
    {
        require(
            ticketNFT.holderOf(ticketID) == msg.sender,
            "Must be the holder to list this ticket"
        );

        ticketNFT.transferFrom(msg.sender, address(this), ticketID);
        ticketListings[ticketID] = TicketListingInfo(price, msg.sender);

        emit Listing(ticketID, msg.sender, price);
    }

    function purchase(uint256 ticketID, string calldata name)
        external
        isValidTicket(ticketID)
        isListedTicket(ticketID)
    {
        TicketListingInfo memory listingInfo = ticketListings[ticketID];

        uint256 fee = (listingInfo.price * FEE_PERCENT) / 100;
        uint256 sellerAmount = listingInfo.price - fee;

        purchaseToken.transferFrom(
            msg.sender,
            listingInfo.seller,
            sellerAmount
        );
        purchaseToken.transferFrom(msg.sender, primaryMarket.admin(), fee);

        ticketNFT.transferFrom(address(this), msg.sender, ticketID);
        ticketNFT.updateHolderName(ticketID, name);

        delete ticketListings[ticketID];
        emit Purchase(msg.sender, ticketID, listingInfo.price, name);
    }

    function delistTicket(uint256 ticketID) external isListedTicket(ticketID) {
        require(
            ticketListings[ticketID].seller == msg.sender,
            "Must be the seller to delist this ticket"
        );

        ticketNFT.transferFrom(address(this), msg.sender, ticketID);
        
        delete ticketListings[ticketID];
        emit Delisting(ticketID);
    }
}
