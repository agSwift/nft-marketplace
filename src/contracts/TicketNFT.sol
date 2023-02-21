// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../contracts/PurchaseToken.sol";
import "../interfaces/ITicketNFT.sol";
import "../interfaces/IPrimaryMarket.sol";

contract TicketNFT is ITicketNFT {
    struct TicketHolder {
        address holder;
        string name;
    }

    string public name;
    string public symbol;

    address public immutable minter;
    PurchaseToken public immutable paymentToken;

    IPrimaryMarket public immutable primaryMarket;
    uint256 public immutable validityDuration;

    uint256 public nftPrice;
    uint256 public lastTicketID;

    mapping(address => uint256) internal _balances;
    mapping(uint256 => TicketHolder) internal _owners;
    mapping(uint256 => address) internal _approvals;
    mapping(uint256 => bool) internal _used;
    mapping(uint256 => uint256) internal _expiryTimes;

    constructor(
        string memory name_,
        string memory symbol_,
        PurchaseToken _paymentToken,
        uint256 _initialNftPrice,
        IPrimaryMarket primaryMarket_
    ) {
        name = name_;
        symbol = symbol_;
        minter = msg.sender;
        paymentToken = _paymentToken;
        primaryMarket = primaryMarket_;
        validityDuration = 864000; // 10 days.
        nftPrice = _initialNftPrice;
        lastTicketID = 0;
    }

    function mint(address holder, string memory holderName) external {
        require(
            msg.sender == address(primaryMarket),
            "Only the primary market can mint tickets"
        );

        uint256 ticketID = lastTicketID + 1;
        // paymentToken.transferFrom(msg.sender, address(0), nftPrice);

        _balances[holder] += 1;
        _owners[ticketID] = TicketHolder(holder, holderName);
        _used[ticketID] = false;
        _expiryTimes[ticketID] = block.timestamp + validityDuration;

        lastTicketID = ticketID;
        emit Transfer(address(0), holder, ticketID);
    }

    function balanceOf(address holder)
        external
        view
        override
        returns (uint256)
    {
        return _balances[holder];
    }

    function ownerOf(uint256 ticketID) external view returns (address) {
        require(lastTicketID >= ticketID, "Ticket does not exist");

        return _owners[ticketID].holder;
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external {
        address ticketHolder = _owners[ticketID].holder;

        require(to != address(0), "'to' address cannot be the zero address");
        require(
            from != address(0),
            "'from' address cannot be the zero address"
        );
        require(
            ticketHolder == from,
            "'from' address is not the owner of this ticket"
        );

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[ticketID].holder = to;
    }

    function isExpiredOrUsed(uint256 ticketID) external view returns (bool) {
        require(lastTicketID >= ticketID, "Ticket does not exist");

        return _used[ticketID] || block.timestamp > _expiryTimes[ticketID];
    }
}
