// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../contracts/PrimaryMarket.sol";
import "../interfaces/ISecondaryMarket.sol";
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
    PrimaryMarket public primaryMarket;

    mapping(uint256 => TicketListingInfo) internal _ticketListings;

    modifier isValidTicket(uint256 ticketID) {
        require(
            !ticketNFT.isExpiredOrUsed(ticketID),
            "Ticket is invalid - has expired or been used"
        );
        _;
    }

    modifier isListedTicket(uint256 ticketID) {
        require(_ticketListings[ticketID].price > 0, "Ticket is not listed");
        _;
    }

    constructor(IERC20 purchaseToken_, PrimaryMarket primaryMarket_) {
        purchaseToken = purchaseToken_;
        primaryMarket = primaryMarket_;
        ticketNFT = primaryMarket._ticketNFT();
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
        _ticketListings[ticketID] = TicketListingInfo(price, msg.sender);

        emit Listing(ticketID, msg.sender, price);
    }

    function purchase(uint256 ticketID, string calldata name)
        external
        isValidTicket(ticketID)
        isListedTicket(ticketID)
    {
        TicketListingInfo memory listingInfo = _ticketListings[ticketID];

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

        delete _ticketListings[ticketID];
        emit Purchase(msg.sender, ticketID, listingInfo.price, name);
    }

    function delistTicket(uint256 ticketID) external isListedTicket(ticketID) {
        require(
            _ticketListings[ticketID].seller == msg.sender,
            "Must be the seller to delist this ticket"
        );

        ticketNFT.transferFrom(address(this), msg.sender, ticketID);

        delete _ticketListings[ticketID];
        emit Delisting(ticketID);
    }

    function getListingInfo(uint256 ticketID)
        external
        view
        returns (TicketListingInfo memory)
    {
        return _ticketListings[ticketID];
    }
}
