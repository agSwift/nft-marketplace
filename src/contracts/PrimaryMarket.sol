// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";
import "../interfaces/IERC20.sol";
import "../contracts/TicketNFT.sol";

contract PrimaryMarket is IPrimaryMarket {
    uint256 public constant MAX_NUM_TICKETS = 1000;
    uint256 public constant TICKET_PRICE = 100e18;

    uint256 public total_minted = 0;

    address public _admin;
    IERC20 public _purchaseToken;
    TicketNFT public _ticketNFT;

    constructor(address admin_, IERC20 purchaseToken) {
        _admin = admin_;
        _purchaseToken = purchaseToken;
        _ticketNFT = new TicketNFT(address(this));
    }

    function admin() external view returns (address) {
        return _admin;
    }

    function purchase(string memory holderName) external {
        require(
            total_minted < MAX_NUM_TICKETS,
            "Maximum number of tickets already sold"
        );

        _purchaseToken.transferFrom(msg.sender, _admin, TICKET_PRICE);
        _ticketNFT.mint(msg.sender, holderName);
        total_minted += 1;

        emit Purchase(msg.sender, holderName);
    }
}
