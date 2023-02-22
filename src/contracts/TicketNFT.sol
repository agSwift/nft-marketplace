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

    uint256 public constant EXPIRY_DURATION = 10 days;

    address public immutable minter;
    PurchaseToken public immutable paymentToken;

    address public primaryMarket;

    uint256 public nftPrice;
    uint256 public lastTicketID;

    mapping(address => uint256) internal _balances;
    mapping(uint256 => TicketHolder) internal _owners;
    mapping(address => address[]) internal _operators;
    mapping(uint256 => address) internal _approvals;
    mapping(uint256 => bool) internal _used;
    mapping(uint256 => uint256) internal _expiryTimes;

    modifier existsTicketID(uint256 ticketID) {
        require(
            ticketID > 0 && ticketID <= lastTicketID,
            "Ticket does not exist"
        );
        _;
    }

    modifier isNotExpiredOrUsed(uint256 ticketID) {
        require(
            !this.isExpiredOrUsed(ticketID),
            "Ticket is invalid - has expired or been used"
        );
        _;
    }

    modifier ticketHolderRequired(uint256 ticketID) {
        require(
            _owners[ticketID].holder == msg.sender,
            "Must be the holder of this ticket"
        );
        _;
    }

    constructor(
        PurchaseToken _paymentToken,
        uint256 _initialNftPrice,
        IPrimaryMarket primaryMarket_
    ) {
        minter = msg.sender;
        paymentToken = _paymentToken;
        primaryMarket = primaryMarket_;
        nftPrice = _initialNftPrice;
        lastTicketID = 0;
    }

    function mint(address holder, string memory holderName) external {
        require(
            msg.sender == address(primaryMarket),
            "Only the primary market can mint tickets"
        );

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
        existsTicketID(ticketID)
        returns (address)
    {
        return _owners[ticketID].holder;
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external existsTicketID(ticketID) isNotExpiredOrUsed(ticketID) {
        address ticketHolder = _owners[ticketID].holder;

        require(
            ticketHolder == from,
            "`from` must be the owner of this ticket"
        );

        require(from != address(0), "`from` must not be the zero address");
        require(to != address(0), "`to` must not be the zero address");

        require(
            ticketHolder == msg.sender ||
                _isOperatorOfHolder(from, msg.sender) ||
                this.getApproved(ticketID) == msg.sender,
            "Unauthorized to transfer this ticket"
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
        existsTicketID(ticketID)
        ticketHolderRequired(ticketID)
    {
        address ticketHolder = _owners[ticketID].holder;

        _approvals[ticketID] = to;
        emit Approval(ticketHolder, to, ticketID);
    }

    function getApproved(uint256 ticketID)
        external
        view
        existsTicketID(ticketID)
        returns (address operator)
    {
        return _approvals[ticketID];
    }

    function holderNameOf(uint256 ticketID)
        external
        view
        existsTicketID(ticketID)
        returns (string memory holderName)
    {
        return _owners[ticketID].name;
    }

    function updateHolderName(uint256 ticketID, string calldata newName)
        external
        existsTicketID(ticketID)
        ticketHolderRequired(ticketID)
    {
        _owners[ticketID].name = newName;
    }

    function setUsed(uint256 ticketID)
        external
        existsTicketID(ticketID)
        isNotExpiredOrUsed(ticketID)
    {
         
    }

    function isExpiredOrUsed(uint256 ticketID)
        external
        view
        existsTicketID(ticketID)
        returns (bool)
    {
        return (block.timestamp > _expiryTimes[ticketID]) || _used[ticketID];
    }

    function _isOperatorOfHolder(address holder, address operator)
        internal
        view
        returns (bool)
    {
        address[] storage userOperators = _operators[holder];

        for (uint256 i = 0; i < userOperators.length; i++) {
            if (userOperators[i] == operator) {
                return true;
            }
        }

        return false;
    }
}
