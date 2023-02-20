// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/IERC20.sol";
import "../interfaces/ITicketNFT.sol";
import "../interfaces/IPrimaryMarket.sol";
import "../interfaces/ISecondaryMarket.sol";

contract TicketNFT is ITicketNFT, IPrimaryMarket, ISecondaryMarket {
    address _admin;
    uint256 _totalSupply;
    IERC20 public _purchaseToken;
    mapping(uint256 => address) _approvals;
    mapping(address => uint256) _balances;
    mapping(uint256 => uint256) public _expiryTimes;
    mapping(uint256 => string) _holderNames;
    mapping(uint256 => address) _holders;
    mapping(uint256 => address) _listers;
    mapping(uint256 => uint256) _prices;
    mapping(uint256 => bool) _ticketUsed;
    uint256 immutable _purchasePrice = 100e18;
    uint256 immutable _saleFee = 50;

    constructor(IERC20 purchaseToken) {
        _admin = msg.sender;
        _totalSupply = 0;
        _purchaseToken = purchaseToken;
    }

    function mint(address holder, string memory holderName) external {
        require(
            msg.sender == address(this),
            "mint: can only be called by primary market"
        ); // Limits to being called by this contract and only purchase function calls mint
        uint256 ticketId = _totalSupply + 1;
        _balances[holder] += 1;
        _expiryTimes[ticketId] = block.timestamp + 10 days;
        _holderNames[ticketId] = holderName;
        _holders[ticketId] = holder;
        _ticketUsed[ticketId] = false;
        _totalSupply = ticketId;
        emit Transfer(address(0), holder, ticketId);
    }

    function balanceOf(address holder) external view returns (uint256) {
        return _balances[holder];
    }

    function holderOf(uint256 ticketID) external view returns (address) {
        require(ticketID <= _totalSupply, "holderOf: ticket doesn't exist");
        return _holders[ticketID];
    }

    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external {
        require(from != address(0), "transferFrom: from cannot be 0");
        require(to != address(0), "transferFrom: to cannot be 0");
        require(
            msg.sender == _holders[ticketID] ||
                msg.sender == _approvals[ticketID] ||
                (msg.sender == address(this) &&
                    (from == _holders[ticketID] ||
                        from == _approvals[ticketID])),
            "transferFrom: msg.sender must be current holder or approved sender"
        );
        require(
            from == _holders[ticketID],
            "transferFrom: ticket not owned by from"
        );
        _approvals[ticketID] = address(0);
        _balances[from] -= 1;
        _balances[to] += 1;
        _holders[ticketID] = to;
        emit Transfer(from, to, ticketID);
        emit Approval(to, address(0), ticketID);
    }

    function approve(address to, uint256 ticketID) external {
        require(ticketID <= _totalSupply, "approve: ticket doesn't exist");
        require(
            msg.sender == _holders[ticketID],
            "approve: msg.sender doesn't own ticket"
        );
        _approvals[ticketID] = to;
        emit Approval(msg.sender, to, ticketID);
    }

    function getApproved(uint256 ticketID) external view returns (address) {
        require(ticketID <= _totalSupply, "getApproved: ticket doesn't exist");
        return _approvals[ticketID];
    }

    function holderNameOf(uint256 ticketID)
        external
        view
        returns (string memory)
    {
        require(ticketID <= _totalSupply, "holderNameOf: ticket doesn't exist");
        return _holderNames[ticketID];
    }

    function updateHolderName(uint256 ticketID, string calldata newName)
        external
    {
        require(
            ticketID <= _totalSupply,
            "updateHolderName: ticket doesn't exist"
        );
        require(
            msg.sender == _holders[ticketID],
            "updateHolderName: msg.sender doesn't own ticket"
        );
        _holderNames[ticketID] = newName;
    }

    function setUsed(uint256 ticketID) external {
        require(msg.sender == _admin, "setUsed: only admin can setUsed");
        require(ticketID <= _totalSupply, "setUsed: ticket doesn't exist");
        require(_ticketUsed[ticketID] == false, "setUsed: ticket already used");
        require(
            _expiryTimes[ticketID] > block.timestamp,
            "setUsed: ticket expired"
        );
        _ticketUsed[ticketID] = true;
    }

    function isExpiredOrUsed(uint256 ticketID) external view returns (bool) {
        require(
            ticketID <= _totalSupply,
            "isExpiredOrUsed: ticket doesn't exist"
        );
        return (_ticketUsed[ticketID] ||
            _expiryTimes[ticketID] <= block.timestamp);
    }

    function admin() external view returns (address) {
        return _admin;
    }

    function purchase(string memory holderName) external {
        require(_totalSupply < 1000, "purchase: maximum tickets reached");
        require(
            _purchaseToken.allowance(msg.sender, address(this)) >=
                _purchasePrice,
            "purchase: insufficient token allowance"
        );
        _purchaseToken.transferFrom(msg.sender, _admin, _purchasePrice);
        this.mint(msg.sender, holderName);
        emit Purchase(msg.sender, holderName);
    }

    function listTicket(uint256 ticketID, uint256 price) external {
        require(
            msg.sender == _holders[ticketID],
            "listTicket: msg.sender doesn't own ticket"
        );
        require(
            _ticketUsed[ticketID] == false &&
                _expiryTimes[ticketID] > block.timestamp,
            "listTicket: ticket is expired/used"
        );
        require(price > 0, "listTicket: price cannot be 0");
        _listers[ticketID] = msg.sender;
        _prices[ticketID] = price;
        this.transferFrom(msg.sender, address(this), ticketID);
        emit Listing(ticketID, msg.sender, price);
    }

    function purchase(uint256 ticketID, string calldata name) external {
        require(
            _listers[ticketID] != address(0) && _prices[ticketID] != 0,
            "purchase: ticket is not listed, missing lister address or price"
        );
        uint256 ticketPrice = _prices[ticketID];
        uint256 ticketFee = _saleFee * (ticketPrice / 1000);
        uint256 ticketRevenue = ticketPrice - ticketFee;
        require(
            _ticketUsed[ticketID] == false &&
                _expiryTimes[ticketID] > block.timestamp,
            "purchase: ticket is expired/used"
        );
        require(
            _purchaseToken.allowance(msg.sender, address(this)) >= ticketPrice,
            "purchase: insufficient token allowance"
        );
        _purchaseToken.transferFrom(
            msg.sender,
            _listers[ticketID],
            ticketRevenue
        );
        _purchaseToken.transferFrom(msg.sender, _admin, ticketFee);
        this.transferFrom(address(this), msg.sender, ticketID);
        _listers[ticketID] = address(0);
        _prices[ticketID] = 0;
        _holderNames[ticketID] = name;
        emit Purchase(msg.sender, ticketID, ticketPrice, name);
    }

    function delistTicket(uint256 ticketID) external {
        require(
            msg.sender == _listers[ticketID],
            "delistTicket: msg.sender didn't list ticket"
        );
        _listers[ticketID] = address(0);
        _prices[ticketID] = 0;
        this.transferFrom(address(this), msg.sender, ticketID);
        emit Delisting(ticketID);
    }
}
