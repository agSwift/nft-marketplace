// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";

contract TicketNFT is ITicketNFT {
    struct TicketHolder {
        address holder;
        string name;
    }

    uint256 public constant EXPIRY_DURATION = 10 days;

    address public primaryMarketAddress;
    uint256 public lastTicketID;

    mapping(address => uint256) internal _balances;
    mapping(uint256 => TicketHolder) internal _owners;
    mapping(address => address[]) internal _operators;
    mapping(uint256 => address) internal _approvals;
    mapping(uint256 => bool) internal _used;
    mapping(uint256 => uint256) internal _expiryTimes;

    modifier existsTicket(uint256 ticketID) {
        require(
            ticketID > 0 && ticketID <= lastTicketID,
            "Ticket does not exist"
        );
        _;
    }

    modifier isValidTicket(uint256 ticketID) {
        require(
            !this.isExpiredOrUsed(ticketID),
            "Ticket is invalid - has expired or been used"
        );
        _;
    }

    modifier ticketHolderRequired(uint256 ticketID) {
        require(
            _owners[ticketID].holder == msg.sender,
            "Only the ticket holder can call this function"
        );
        _;
    }

    modifier primaryMarketRequired() {
        require(
            msg.sender == primaryMarketAddress,
            "Only the primary market can call this function"
        );
        _;
    }

    constructor(address primaryMarketAddress_) {
        primaryMarketAddress = primaryMarketAddress_;
        lastTicketID = 0;
    }

    function mint(address holder, string memory holderName)
        external
        primaryMarketRequired
    {
        uint256 ticketID = lastTicketID + 1;

        _balances[holder] += 1;
        _owners[ticketID] = TicketHolder(holder, holderName);
        _used[ticketID] = false;
        _expiryTimes[ticketID] = block.timestamp + EXPIRY_DURATION;

        lastTicketID = ticketID;
        emit Transfer(address(0), holder, ticketID);
    }

    function balanceOf(address holder) external view returns (uint256) {
        return _balances[holder];
    }

    function holderOf(uint256 ticketID)
        external
        view
        existsTicket(ticketID)
        returns (address)
    {
        return _owners[ticketID].holder;
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external existsTicket(ticketID) isValidTicket(ticketID) {
        address ticketHolder = _owners[ticketID].holder;

        require(
            ticketHolder == from,
            "`from` must be the owner of this ticket"
        );

        require(from != address(0), "`from` must not be the zero address");
        require(to != address(0), "`to` must not be the zero address");

        require(
            ticketHolder == msg.sender ||
                this.getApproved(ticketID) == msg.sender,
            "Ticket holder or approved address required"
        );

        _balances[from] -= 1;
        _balances[to] += 1;

        _owners[ticketID].holder = to;
        emit Transfer(from, to, ticketID);

        _approvals[ticketID] = address(0);
        emit Approval(from, address(0), ticketID);
    }

    function approve(address to, uint256 ticketID)
        external
        existsTicket(ticketID)
        ticketHolderRequired(ticketID)
    {
        address ticketHolder = _owners[ticketID].holder;

        _approvals[ticketID] = to;
        emit Approval(ticketHolder, to, ticketID);
    }

    function getApproved(uint256 ticketID)
        external
        view
        existsTicket(ticketID)
        returns (address operator)
    {
        return _approvals[ticketID];
    }

    function holderNameOf(uint256 ticketID)
        external
        view
        existsTicket(ticketID)
        returns (string memory holderName)
    {
        return _owners[ticketID].name;
    }

    function updateHolderName(uint256 ticketID, string calldata newName)
        external
        existsTicket(ticketID)
        ticketHolderRequired(ticketID)
    {
        _owners[ticketID].name = newName;
    }

    function setUsed(uint256 ticketID)
        external
        existsTicket(ticketID)
        isValidTicket(ticketID)
        primaryMarketRequired
    {
        _used[ticketID] = true;
    }

    function isExpiredOrUsed(uint256 ticketID)
        external
        view
        existsTicket(ticketID)
        returns (bool)
    {
        return (block.timestamp > _expiryTimes[ticketID]) || _used[ticketID];
    }
}
