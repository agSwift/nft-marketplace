// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../src/contracts/TicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/PurchaseToken.sol";

import "../src/interfaces/IPrimaryMarket.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/interfaces/IERC20.sol";

contract TicketNFTTest is Test {
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

    IERC20 public purchaseToken;
    IPrimaryMarket public primaryMarket;
    ITicketNFT public ticketNFT;

    address primaryMarketAdmin = makeAddr("primaryMarketAdmin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(primaryMarketAdmin, purchaseToken);
        ticketNFT = new TicketNFT(address(primaryMarket));
    }

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

    // function testBalanceOf() public {
    //     vm.prank(address(primaryMarket));
    //     assertEq(ticketNFT.balanceOf(alice), 0);
    // }
}
