// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/contracts/TicketNFT.sol";

contract SecondaryMarketTest is Test {
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

    uint256 public constant TICKET_PRICE = 100e18;

    TicketNFT public ticketNFT;
    PurchaseToken public purchaseToken;
    PrimaryMarket public primaryMarket;
    SecondaryMarket public secondaryMarket;

    address public primaryMarketAdmin = makeAddr("primaryMarketAdmin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(primaryMarketAdmin, purchaseToken);
        ticketNFT = new TicketNFT(address(primaryMarket));

        secondaryMarket = new SecondaryMarket(
            ticketNFT,
            purchaseToken,
            primaryMarket
        );

        vm.deal(alice, 1_000_000 ether);
        vm.deal(bob, 1_000_000 ether);
    }

    // function _buyTicket(address holder, string memory holderName) internal {
    //     vm.startPrank(holder);

    //     purchaseToken.mint{value: TICKET_PRICE}();
    //     purchaseToken.approve(address(primaryMarket), TICKET_PRICE);
    //     primaryMarket.purchase(holderName);

    //     vm.stopPrank();
    // }

    function testListTicketNotExists() public {
        vm.expectRevert("Ticket does not exist");
        secondaryMarket.listTicket(10, 1);
    }

    function testListTicketNotHolder() public {


        vm.startPrank(alice);
        purchaseToken.mint{value: TICKET_PRICE}();
        purchaseToken.approve(address(primaryMarket), TICKET_PRICE);
        primaryMarket.purchase("alice");
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert("Must be the holder to list this ticket");

        // purchaseToken.mint{value: TICKET_PRICE}();
        // purchaseToken.approve(address(secondaryMarket), TICKET_PRICE);

        secondaryMarket.listTicket(1, 100 ether);
    }
}
