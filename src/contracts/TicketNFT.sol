// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../contracts/PurchaseToken.sol";
import "../interfaces/ITicketNFT.sol";

contract TicketNFT is ITicketNFT {
    struct TicketHolder {
        address holder;
        string name;
    }

    string public override name;
    string public override symbol;

    address public immutable minter;
    PurchaseToken public immutable paymentToken;

    uint256 public immutable nftPrice;
    uint256 public lastTokenId;

    mapping(address => uint256) internal _balances;
    mapping(uint256 => TicketHolder) internal _owners;
    mapping(uint256 => uint256) internal _startTimes;

    constructor(
        string memory name_,
        string memory symbol_,
        PurchaseToken _paymentToken
    ) {
        name = name_;
        symbol = symbol_;
        minter = msg.sender;
        paymentToken = _paymentToken;
        nftPrice = 1 * 100**18;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId].holder;
    }

    function mint(address holder, string memory holderName)
        external
    {
        require(msg.sender == minter, "Only minter can mint");

        uint256 tokenId = lastTokenId + 1;
        paymentToken.transferFrom(msg.sender, address(0), nftPrice);

        _balances[holder] += 1;
        _owners[tokenId] = TicketHolder(holder, holderName);
        _startTimes[tokenId] = block.timestamp;

        lastTokenId = tokenId;
        emit Transfer(address(0), holder, tokenId);
    }















    

}