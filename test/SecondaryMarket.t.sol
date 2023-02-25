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
        address holder;
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
    uint256 public constant FEE_PERCENT = 5;
    uint256 public constant LIST_PRICE = 3 ether;

    TicketNFT public ticketNFT;
    PurchaseToken public purchaseToken;
    PrimaryMarket public primaryMarket;
    SecondaryMarket public secondaryMarket;

    address public primaryMarketAdmin = makeAddr("primaryMarketAdmin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public approved = makeAddr("approved");

    function setUp() public virtual {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(primaryMarketAdmin, purchaseToken);
        ticketNFT = primaryMarket._ticketNFT();

        secondaryMarket = new SecondaryMarket(purchaseToken, primaryMarket);

        vm.deal(alice, 1_000_000 ether);
        vm.deal(bob, 1_000_000 ether);
    }

    function _buyTicket(address holder, string memory name) internal {
        vm.startPrank(holder);
        purchaseToken.mint{value: TICKET_PRICE}();
        purchaseToken.approve(address(primaryMarket), TICKET_PRICE);
        primaryMarket.purchase(name);
        vm.stopPrank();
    }

    function _listTicketOnSecondary(
        address holder,
        uint256 ticketID,
        uint256 listPrice
    ) internal {
        vm.startPrank(holder);
        ticketNFT.approve(address(secondaryMarket), ticketID);
        secondaryMarket.listTicket(1, listPrice);
        vm.stopPrank();
    }
}

contract ListTicketSecondaryMarketTest is BaseSecondaryMarketTest {
    function setUp() public override {
        super.setUp();
        _buyTicket(alice, "alice");
    }

    function testListTicketExpired() public {
        vm.warp(EXPIRY_DURATION + 1 minutes);
        vm.expectRevert("Ticket is invalid - has expired or been used");
        secondaryMarket.listTicket(1, LIST_PRICE);
    }

    function testListTicketUsed() public {
        vm.prank(primaryMarketAdmin);
        ticketNFT.setUsed(1);

        vm.expectRevert("Ticket is invalid - has expired or been used");
        secondaryMarket.listTicket(1, LIST_PRICE);
    }

    function testListTicketNotHolder() public {
        vm.prank(bob);
        vm.expectRevert("Must be the holder to list this ticket");
        secondaryMarket.listTicket(1, LIST_PRICE);
    }

    function testListTicketApproved() public {
        address approved = makeAddr("approved");

        vm.prank(alice);
        ticketNFT.approve(approved, 1);

        vm.prank(approved);
        vm.expectRevert("Must be the holder to list this ticket");
        secondaryMarket.listTicket(1, LIST_PRICE);
    }

    function testListTicket() public {
        vm.startPrank(alice);
        ticketNFT.approve(address(secondaryMarket), 1);

        vm.expectEmit(true, true, false, true);
        emit Listing(1, alice, LIST_PRICE);
        secondaryMarket.listTicket(1, LIST_PRICE);

        assertEq(ticketNFT.holderOf(1), address(secondaryMarket));
        assertEq(secondaryMarket.getListingInfo(1).price, LIST_PRICE);
        assertEq(secondaryMarket.getListingInfo(1).holder, alice);

        vm.stopPrank();
    }
}

contract PurchaseSecondaryMarketTest is BaseSecondaryMarketTest {
    function setUp() public override {
        super.setUp();
        _buyTicket(alice, "alice");
        _listTicketOnSecondary(alice, 1, LIST_PRICE);
    }

    function testPurchaseTicketExpired() public {
        vm.warp(EXPIRY_DURATION + 1 minutes);
        vm.expectRevert("Ticket is invalid - has expired or been used");
        secondaryMarket.purchase(1, "bob");
    }

    function testPurchaseTicketUsed() public {
        vm.prank(primaryMarketAdmin);
        ticketNFT.setUsed(1);

        vm.expectRevert("Ticket is invalid - has expired or been used");
        secondaryMarket.purchase(1, "bob");
    }

    function testPurchaseTicketNotListed() public {
        _buyTicket(bob, "bob");

        vm.prank(alice);
        vm.expectRevert("Ticket is not listed");
        secondaryMarket.purchase(2, "alice");
    }

    function testPurchaseTicketNotExists() public {
        vm.prank(alice);
        vm.expectRevert("Ticket does not exist");
        secondaryMarket.purchase(2, "alice");
    }

    function testPurchaseTicket() public {
        vm.startPrank(bob);
        purchaseToken.mint{value: LIST_PRICE}();
        purchaseToken.approve(address(secondaryMarket), LIST_PRICE);

        uint256 bobStartBalance = purchaseToken.balanceOf(bob);
        uint256 primaryMarketAdminStartBalance = purchaseToken.balanceOf(
            primaryMarketAdmin
        );

        vm.expectEmit(true, true, true, true);
        emit Purchase(bob, 1, LIST_PRICE, "bob");
        secondaryMarket.purchase(1, "bob");

        assertEq(ticketNFT.holderOf(1), bob);
        assertEq(ticketNFT.holderNameOf(1), "bob");
        assertEq(secondaryMarket.getListingInfo(1).price, 0);
        assertEq(secondaryMarket.getListingInfo(1).holder, address(0));
        assertEq(purchaseToken.balanceOf(bob), bobStartBalance - LIST_PRICE);
        assertEq(
            purchaseToken.balanceOf(primaryMarketAdmin),
            primaryMarketAdminStartBalance + ((LIST_PRICE * FEE_PERCENT) / 100)
        );

        vm.stopPrank();
    }
}

contract DelistTicketSecondaryMarketTest is BaseSecondaryMarketTest {
    function setUp() public override {
        super.setUp();

        _buyTicket(alice, "alice");

        vm.prank(alice);
        ticketNFT.approve(approved, 1);

        _listTicketOnSecondary(alice, 1, LIST_PRICE);
    }

    function testDelistTicketNotListed() public {
        _buyTicket(bob, "bob");

        vm.prank(alice);
        vm.expectRevert("Ticket is not listed");
        secondaryMarket.delistTicket(2);
    }

    function testDelistTicketNotExists() public {
        vm.prank(alice);
        vm.expectRevert("Ticket is not listed");
        secondaryMarket.delistTicket(2);
    }

    function testDelistNotHolder() public {
        vm.prank(bob);
        vm.expectRevert("Must be the holder to delist this ticket");
        secondaryMarket.delistTicket(1);
    }

    function testDelistApproved() public {
        vm.prank(approved);
        vm.expectRevert("Must be the holder to delist this ticket");
        secondaryMarket.delistTicket(1);
    }

    function testDelistTicket() public {
        vm.startPrank(alice);
        vm.expectEmit(true, false, false, false);
        emit Delisting(1);
        secondaryMarket.delistTicket(1);

        assertEq(ticketNFT.holderOf(1), alice);
        assertEq(secondaryMarket.getListingInfo(1).price, 0);
        assertEq(secondaryMarket.getListingInfo(1).holder, address(0));

        vm.stopPrank();
    }
}
