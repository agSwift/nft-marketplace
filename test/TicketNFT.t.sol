// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../src/contracts/TicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/PurchaseToken.sol";

import "../src/interfaces/IPrimaryMarket.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/interfaces/IERC20.sol";

contract BaseTicketNFTTest is Test {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed ticketID
    );

    event Approval(
        address indexed holder,
        address indexed approved,
        uint256 indexed ticketID
    );

    uint256 public constant EXPIRY_DURATION = 10 days;

    IERC20 public purchaseToken;
    IPrimaryMarket public primaryMarket;
    ITicketNFT public ticketNFT;

    address primaryMarketAdmin = makeAddr("primaryMarketAdmin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public virtual {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(primaryMarketAdmin, purchaseToken);
        ticketNFT = new TicketNFT(address(primaryMarket));
    }
}

contract MintTicketNFTTest is BaseTicketNFTTest {
    function testMintAsPrimaryMarket() public {
        assertEq(ticketNFT.balanceOf(alice), 0);

        vm.prank(address(primaryMarket));
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1);
        ticketNFT.mint(alice, "alice");

        assertEq(ticketNFT.balanceOf(alice), 1);
        assertEq(ticketNFT.holderOf(1), alice);
        assertEq(ticketNFT.holderNameOf(1), "alice");
    }

    function testMintAsNotPrimaryMarket() public {
        assertEq(ticketNFT.balanceOf(alice), 0);

        vm.prank(alice);
        vm.expectRevert("Only the primary market can call this function");
        ticketNFT.mint(alice, "alice");

        assertEq(ticketNFT.balanceOf(alice), 0);
    }

    function testMintTwiceToSameAddress() public {
        assertEq(ticketNFT.balanceOf(alice), 0);

        vm.startPrank(address(primaryMarket));
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1);
        ticketNFT.mint(alice, "alice");

        assertEq(ticketNFT.balanceOf(alice), 1);
        assertEq(ticketNFT.holderOf(1), alice);
        assertEq(ticketNFT.holderNameOf(1), "alice");

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 2);
        ticketNFT.mint(alice, "alice");

        assertEq(ticketNFT.balanceOf(alice), 2);
        assertEq(ticketNFT.holderOf(1), alice);
        assertEq(ticketNFT.holderNameOf(1), "alice");
        assertEq(ticketNFT.holderOf(2), alice);
        assertEq(ticketNFT.holderNameOf(2), "alice");

        vm.stopPrank();
    }

    function testMintTwiceToDifferentAddresses() public {
        assertEq(ticketNFT.balanceOf(alice), 0);
        assertEq(ticketNFT.balanceOf(bob), 0);

        vm.startPrank(address(primaryMarket));
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), bob, 1);
        ticketNFT.mint(bob, "bob");

        assertEq(ticketNFT.balanceOf(alice), 0);
        assertEq(ticketNFT.balanceOf(bob), 1);
        assertEq(ticketNFT.holderOf(1), bob);
        assertEq(ticketNFT.holderNameOf(1), "bob");

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 2);
        ticketNFT.mint(alice, "alice");

        assertEq(ticketNFT.balanceOf(alice), 1);
        assertEq(ticketNFT.balanceOf(bob), 1);
        assertEq(ticketNFT.holderOf(1), bob);
        assertEq(ticketNFT.holderNameOf(1), "bob");
        assertEq(ticketNFT.holderOf(2), alice);
        assertEq(ticketNFT.holderNameOf(2), "alice");

        vm.stopPrank();
    }
}

contract TransferTicketNFTTest is BaseTicketNFTTest {
    function setUp() public override {
        super.setUp();

        vm.prank(address(primaryMarket));
        ticketNFT.mint(alice, "alice");
    }

    function testTransferWithNotExistsTicket() public {
        vm.expectRevert("Ticket does not exist");
        ticketNFT.transferFrom(alice, bob, 10);
    }

    function testTransferWithExpiredTicket() public {
        vm.warp(EXPIRY_DURATION + 1 minutes);
        vm.expectRevert("Ticket is invalid - has expired or already been used");
        ticketNFT.transferFrom(alice, bob, 1);
    }

    function testTransferWithUsedTicket() public {
        vm.prank(primaryMarketAdmin);
        ticketNFT.setUsed(1);
        vm.expectRevert("Ticket is invalid - has expired or already been used");
        ticketNFT.transferFrom(alice, bob, 1);
    }

    function testTransferFromNotHolder() public {
        vm.expectRevert("`from` must be the owner of this ticket");
        ticketNFT.transferFrom(bob, alice, 1);
    }

    function testTransferToSelf() public {
        vm.expectRevert("`from` and `to` must not be the same address");
        ticketNFT.transferFrom(alice, alice, 1);
    }

    function testTransferFromZeroAddress() public {
        vm.prank(address(primaryMarket));
        ticketNFT.mint(address(0), "zero");

        vm.expectRevert("`from` must not be the zero address");
        ticketNFT.transferFrom(address(0), alice, 2);
    }

    function testTransferToZeroAddress() public {
        vm.expectRevert("`to` must not be the zero address");
        ticketNFT.transferFrom(alice, address(0), 1);
    }

    function testTransferCallerNotHolderOrApproved() public {
        address notHolderNotApproved = makeAddr("notHolderNotApproved");
        vm.prank(notHolderNotApproved);
        vm.expectRevert("Ticket holder or approved address required");
        ticketNFT.transferFrom(alice, bob, 1);
    }

    function testTransferUsingApprovedAddress() public {
        vm.prank(alice);
        address approved = makeAddr("approved");
        ticketNFT.approve(approved, 1);

        vm.prank(approved);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        ticketNFT.transferFrom(alice, bob, 1);

        assertEq(ticketNFT.balanceOf(alice), 0);
        assertEq(ticketNFT.balanceOf(bob), 1);
        assertEq(ticketNFT.holderOf(1), bob);
    }

    function testTransferUsingHolderAddress() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        ticketNFT.transferFrom(alice, bob, 1);

        assertEq(ticketNFT.balanceOf(alice), 0);
        assertEq(ticketNFT.balanceOf(bob), 1);
        assertEq(ticketNFT.holderOf(1), bob);
    }
}

contract ApproveTicketNFTTest is BaseTicketNFTTest {
    function setUp() public override {
        super.setUp();

        vm.prank(address(primaryMarket));
        ticketNFT.mint(alice, "alice");
    }

    function testApproveWithNotExistsTicket() public {
        vm.expectRevert("Ticket does not exist");
        ticketNFT.approve(bob, 10);
    }

    function testApproveNotHolder() public {
        vm.expectRevert("Only the ticket holder can call this function");
        ticketNFT.approve(bob, 1);
    }

    function testApproveAsHolder() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Approval(alice, bob, 1);

        ticketNFT.approve(bob, 1);

        assertEq(ticketNFT.getApproved(1), bob);
    }
}

contract UpdateHolderNameNFTTest is BaseTicketNFTTest {
    function setUp() public override {
        super.setUp();

        vm.prank(address(primaryMarket));
        ticketNFT.mint(alice, "alice");
    }

    function testUpdateHolderNameWithNotExistsTicket() public {
        vm.expectRevert("Ticket does not exist");
        ticketNFT.updateHolderName(10, "bob");
    }

    function testUpdateHolderNameNotHolder() public {
        vm.expectRevert("Only the ticket holder can call this function");
        ticketNFT.updateHolderName(1, "bob");
    }

    function testUpdateHolderNameAsHolder() public {
        vm.prank(alice);
        ticketNFT.updateHolderName(1, "newName");

        assertEq(ticketNFT.holderNameOf(1), "newName");
    }
}

contract SetUsedNFTTest is BaseTicketNFTTest {
    function setUp() public override {
        super.setUp();

        vm.prank(address(primaryMarket));
        ticketNFT.mint(alice, "alice");
    }

    function testSetUsedWithNotExistsTicket() public {
        vm.expectRevert("Ticket does not exist");
        ticketNFT.setUsed(10);
    }

    function testSetUsedWithExpiredTicket() public {
        vm.warp(EXPIRY_DURATION + 1 minutes);
        vm.expectRevert("Ticket is invalid - has expired or already been used");
        ticketNFT.setUsed(1);
    }

    function testSetUsedWithUsedTicket() public {
        vm.startPrank(primaryMarketAdmin);
        ticketNFT.setUsed(1);

        vm.expectRevert("Ticket is invalid - has expired or already been used");
        ticketNFT.setUsed(1);

        vm.stopPrank();
    }

    function testSetUsedAsNonPrimaryMarketAdmin() public {
        vm.expectRevert("Only the primary market admin can call this function");
        ticketNFT.setUsed(1);
    }

    function testSetUsedAsPrimaryMarketAdmin() public {
        vm.startPrank(primaryMarketAdmin);
        ticketNFT.setUsed(1);

        assertTrue(ticketNFT.isExpiredOrUsed(1));
    }
}

contract IsExpiredOrUsedNFTTest is BaseTicketNFTTest {
    function setUp() public override {
        super.setUp();

        vm.prank(address(primaryMarket));
        ticketNFT.mint(alice, "alice");
    }

    function testIsExpiredOrUsedWithNotExistsTicket() public {
        vm.expectRevert("Ticket does not exist");
        ticketNFT.isExpiredOrUsed(10);
    }

    function testIsExpiredOrUsedWithExpiredTicket() public {
        vm.warp(EXPIRY_DURATION + 1 minutes);
        assertTrue(ticketNFT.isExpiredOrUsed(1));
    }

    function testIsExpiredOrUsedWithUsedTicket() public {
        vm.startPrank(primaryMarketAdmin);
        ticketNFT.setUsed(1);

        assertTrue(ticketNFT.isExpiredOrUsed(1));

        vm.stopPrank();
    }

    function testIsExpiredOrUsedWithValidTicket() public {
        assertFalse(ticketNFT.isExpiredOrUsed(1));
    }
}
