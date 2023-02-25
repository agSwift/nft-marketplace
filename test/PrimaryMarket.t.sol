// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/PurchaseToken.sol";

contract PrimaryMarketTest is Test {
    event Purchase(address indexed holder, string indexed holderName);

    uint256 public constant MAX_NUM_TICKETS = 1000;
    uint256 public constant TICKET_PRICE = 100e18;

    PurchaseToken public purchaseToken;
    PrimaryMarket public primaryMarket;

    address primaryMarketAdmin = makeAddr("primaryMarketAdmin");
    address alice = makeAddr("alice");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(primaryMarketAdmin, purchaseToken);
        vm.deal(alice, 1_000_000 ether);
    }

    function testAdmin() public {
        assertEq(primaryMarket.admin(), primaryMarketAdmin);
    }

    function testPurchaseWithInsufficientBalance() public {
        vm.startPrank(alice);

        purchaseToken.mint{value: TICKET_PRICE - 1}();
        purchaseToken.approve(address(primaryMarket), TICKET_PRICE - 1);

        vm.expectRevert("ERC20: insufficient allowance");
        primaryMarket.purchase("alice");
        vm.stopPrank();

        assertEq(purchaseToken.balanceOf(primaryMarketAdmin), 0);
        assertEq(primaryMarket.total_minted(), 0);
    }

    function testPurchaseWithSufficientBalance() public {
        vm.startPrank(alice);

        purchaseToken.mint{value: TICKET_PRICE}();
        purchaseToken.approve(address(primaryMarket), TICKET_PRICE);
        uint256 startBalance = purchaseToken.balanceOf(alice);

        vm.expectEmit(true, true, false, false);
        emit Purchase(alice, "alice");

        primaryMarket.purchase("alice");
        vm.stopPrank();

        assertEq(purchaseToken.balanceOf(primaryMarketAdmin), TICKET_PRICE);
        assertEq(purchaseToken.balanceOf(alice), startBalance - TICKET_PRICE);
        assertEq(primaryMarket.total_minted(), 1);
        assertEq(primaryMarket._ticketNFT().holderOf(1), alice);
        assertEq(primaryMarket._ticketNFT().holderNameOf(1), "alice");
    }

    function testPurchaseAllTicketsSoldOut() public {
        vm.startPrank(alice);

        uint256 balance_req = TICKET_PRICE * MAX_NUM_TICKETS;
        purchaseToken.mint{value: balance_req}();
        purchaseToken.approve(address(primaryMarket), balance_req);

        for (uint256 i = 0; i < MAX_NUM_TICKETS; i++) {
            primaryMarket.purchase("alice");
        }

        assertEq(primaryMarket.total_minted(), MAX_NUM_TICKETS);

        vm.expectRevert("Maximum number of tickets already sold");
        primaryMarket.purchase("alice");
        vm.stopPrank();
    }
}
