// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/contracts/TicketNFT.sol";

contract BaseSecondaryMarketTest is Test {
    struct TicketListingInfo {
        uint256 price;
        address seller;
    }

    event Listing(
        uint256 indexed ticketID,
        address indexed holder,
        uint256 price
    );

    event Purchase(
        address indexed purchaser,
        uint256 indexed ticketID,
        uint256 price,
        string newName
    );

    event Delisting(uint256 indexed ticketID);

    uint256 public constant EXPIRY_DURATION = 10 days;
    uint256 public constant TICKET_PRICE = 100e18;

    TicketNFT public ticketNFT;
    PurchaseToken public purchaseToken;
    PrimaryMarket public primaryMarket;
    SecondaryMarket public secondaryMarket;

    address public primaryMarketAdmin = makeAddr("primaryMarketAdmin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public virtual {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(primaryMarketAdmin, purchaseToken);
        ticketNFT = primaryMarket._ticketNFT();

        secondaryMarket = new SecondaryMarket(purchaseToken, primaryMarket);

        vm.deal(alice, 1_000_000 ether);
        vm.deal(bob, 1_000_000 ether);
    }
}

contract ListTicketSecondaryMarketTest is BaseSecondaryMarketTest {
    function setUp() public override {
        super.setUp();

        // Buy a ticket for Alice.
        vm.startPrank(alice);
        purchaseToken.mint{value: TICKET_PRICE}();
        purchaseToken.approve(address(primaryMarket), TICKET_PRICE);
        primaryMarket.purchase("alice");
        vm.stopPrank();
    }

    function testListTicketExpired() public {
        vm.warp(EXPIRY_DURATION + 1 minutes);
        vm.expectRevert("Ticket is invalid - has expired or been used");
        secondaryMarket.listTicket(1, 10 ether);
    }

    function testListTicketUsed() public {
        vm.prank(primaryMarketAdmin);
        ticketNFT.setUsed(1);

        vm.expectRevert("Ticket is invalid - has expired or been used");
        secondaryMarket.listTicket(1, 10 ether);
    }

    function testListTicketNotHolder() public {
        vm.prank(bob);
        vm.expectRevert("Must be the holder to list this ticket");
        secondaryMarket.listTicket(1, 10 ether);
    }

    function testListTicketApproved() public {
        address approved = makeAddr("approved");

        vm.prank(alice);
        ticketNFT.approve(approved, 1);

        vm.prank(approved);
        vm.expectRevert("Must be the holder to list this ticket");
        secondaryMarket.listTicket(1, 10 ether);
    }

    function testListTicket() public {
        vm.startPrank(alice);
        ticketNFT.approve(address(secondaryMarket), 1);

        vm.expectEmit(true, true, false, true);
        emit Listing(1, alice, 10 ether);
        secondaryMarket.listTicket(1, 10 ether);

        assertEq(ticketNFT.holderOf(1), address(secondaryMarket));
        assertEq(secondaryMarket.getListingInfo(1).price, 10 ether);
        assertEq(secondaryMarket.getListingInfo(1).seller, alice);

        vm.stopPrank();
    }
}
