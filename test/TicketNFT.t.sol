// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/contracts/TicketNFT.sol";

contract BaseTicketNFTTest is Test {
    // TicketNFT Events
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

    // Primary Market Events
    event Purchase(address indexed holder, string indexed holderName);

    // Secondary Market Events
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

    uint256 public ticketPriceEth = 1e18;
    uint256 public ticketPrice = 100e18;

    PurchaseToken public token;
    TicketNFT public nft;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        token = new PurchaseToken();
        nft = new TicketNFT(token);
    }

    // Add Purchase Tokens to `recipient` to affort `amount` tickets
    function _topUpTokens(address recipient, uint256 amount) internal {
        vm.deal(recipient, amount * ticketPriceEth);
        vm.prank(recipient);
        token.mint{value: amount * ticketPriceEth}();
    }

    function _buyTicket(address recipient, string memory recipientName)
        internal
    {
        _topUpTokens(recipient, 1);
        vm.prank(recipient);
        token.approve(address(nft), ticketPrice);
        vm.prank(recipient);
        nft.purchase(recipientName);
    }
}

contract TicketNFTTest is BaseTicketNFTTest {
    function testMint() public {
        vm.prank(address(nft));
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1);
        nft.mint(alice, "alice");
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.holderOf(1), alice);
        assertEq(nft.getApproved(1), address(0));
        assertEq(nft.holderNameOf(1), "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
    }

    function testMintUnauthorized() public {
        _topUpTokens(alice, 1);
        vm.prank(alice);
        vm.expectRevert("mint: can only be called by primary market");
        nft.mint(alice, "alice");
        assertEq(nft.balanceOf(alice), 0);
    }

    function testHolderOf() public {
        _buyTicket(alice, "alice");
        assertEq(nft.holderOf(1), alice);
    }

    function testHolderNameOf() public {
        _buyTicket(alice, "alice");
        assertEq(nft.holderNameOf(1), "alice");
    }

    function testTransfer() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        vm.expectEmit(true, true, true, false);
        emit Approval(bob, address(0), 1);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.holderOf(1), bob);
        assertEq(nft.getApproved(1), address(0));
        assertEq(nft.holderNameOf(1), "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
        vm.prank(bob);
        nft.updateHolderName(1, "bob");
        assertEq(nft.holderNameOf(1), "bob");
    }

    function testTransferInvalid() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        vm.expectRevert("transferFrom: from cannot be 0");
        nft.transferFrom(address(0), bob, 2);
        vm.prank(alice);
        vm.expectRevert("transferFrom: to cannot be 0");
        nft.transferFrom(alice, address(0), 2);
    }

    function testTransferUnauthorized() public {
        _buyTicket(alice, "alice");
        vm.prank(bob);
        vm.expectRevert(
            "transferFrom: msg.sender must be current holder or approved sender"
        );
        nft.transferFrom(alice, bob, 1);
    } // TODO: unnecessary?

    function testApproval() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Approval(alice, bob, 1);
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), bob);
    }

    function testApprovalUnauthorized() public {
        _buyTicket(alice, "alice");
        vm.prank(bob);
        vm.expectRevert("approve: msg.sender doesn't own ticket");
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), address(0));
    }

    function testTransferFrom() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.approve(bob, 1);
        vm.prank(bob);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, charlie, 1);
        vm.expectEmit(true, true, true, false);
        emit Approval(charlie, address(0), 1);
        nft.transferFrom(alice, charlie, 1);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(charlie), 1);
        assertEq(nft.holderOf(1), charlie);
        assertEq(nft.getApproved(1), address(0));
    }

    function testTransferFromInvalid() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), bob);
        vm.prank(bob);
        vm.expectRevert("transferFrom: from cannot be 0");
        nft.transferFrom(address(0), charlie, 1);
        vm.prank(bob);
        vm.expectRevert("transferFrom: to cannot be 0");
        nft.transferFrom(alice, address(0), 1);
        vm.prank(bob);
        vm.expectRevert("transferFrom: ticket not owned by from");
        nft.transferFrom(bob, charlie, 1);
        vm.prank(bob);
        vm.expectRevert("transferFrom: ticket not owned by from");
        nft.transferFrom(charlie, bob, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(charlie), 0);
        assertEq(nft.holderOf(1), alice);
        assertEq(nft.getApproved(1), bob);
    }

    function testTransferFromUnauthorized() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), bob);
        vm.prank(charlie);
        vm.expectRevert(
            "transferFrom: msg.sender must be current holder or approved sender"
        );
        nft.transferFrom(alice, charlie, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(charlie), 0);
        assertEq(nft.holderOf(1), alice);
        assertEq(nft.getApproved(1), bob);
    }

    function testIsExpiredOrUsedInvalid() public {
        vm.expectRevert("isExpiredOrUsed: ticket doesn't exist");
        nft.isExpiredOrUsed(1);
    }

    function testExpiry() public {
        _buyTicket(alice, "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
        vm.warp(block.timestamp + 10 days - 1);
        assertEq(nft.isExpiredOrUsed(1), false);
        vm.warp(block.timestamp + 1);
        assertEq(nft.isExpiredOrUsed(1), true);
    }

    function testSetUsed() public {
        _buyTicket(alice, "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
        vm.prank(address(this));
        nft.setUsed(1);
        assertEq(nft.isExpiredOrUsed(1), true);
    }

    function testSetUsedNonExistent() public {
        vm.expectRevert("setUsed: ticket doesn't exist");
        nft.setUsed(1);
    }

    function testSetUsedAlreadyUsed() public {
        _buyTicket(alice, "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
        vm.prank(address(this));
        nft.setUsed(1);
        assertEq(nft.isExpiredOrUsed(1), true);
        vm.prank(address(this));
        vm.expectRevert("setUsed: ticket already used");
        nft.setUsed(1);
    }

    function testSetUsedExpired() public {
        _buyTicket(alice, "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
        vm.warp(block.timestamp + 10 days);
        vm.prank(address(this));
        vm.expectRevert("setUsed: ticket expired");
        nft.setUsed(1);
    }

    function testSetUsedUnauthorized() public {
        _buyTicket(alice, "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
        vm.warp(block.timestamp + 10 days);
        vm.prank(bob);
        vm.expectRevert("setUsed: only admin can setUsed");
        nft.setUsed(1);
    }
}

contract PrimaryMarketTest is BaseTicketNFTTest {
    function testAdmin() public {
        assertEq(address(this), nft.admin());
    }

    function testPrimaryPurchase() public {
        _topUpTokens(alice, 1);
        vm.prank(alice);
        token.approve(address(nft), ticketPrice);
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1);
        vm.expectEmit(true, true, false, false);
        emit Purchase(alice, "alice");
        nft.purchase("alice");
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.holderOf(1), alice);
        assertEq(nft.getApproved(1), address(0));
        assertEq(nft.holderNameOf(1), "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
    }

    function testPrimaryPurchaseInsufficientBalance() public {
        vm.deal(alice, ticketPriceEth);
        vm.prank(alice);
        token.mint{value: ticketPriceEth - 1}();
        vm.prank(alice);
        token.approve(address(nft), ticketPrice);
        vm.prank(alice);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        nft.purchase("alice");
        assertEq(nft.balanceOf(alice), 0);
    }

    function testPrimaryPurchaseInsufficientAllowance() public {
        vm.deal(alice, ticketPriceEth);
        vm.prank(alice);
        token.mint{value: ticketPriceEth}();
        vm.prank(alice);
        token.approve(address(nft), ticketPrice - 1);
        vm.prank(alice);
        vm.expectRevert("purchase: insufficient token allowance");
        nft.purchase("alice");
        assertEq(nft.balanceOf(alice), 0);
    }

    function testPrimaryPurchases() public {
        _topUpTokens(alice, 2);
        vm.prank(alice);
        token.approve(address(nft), ticketPrice * 2);
        vm.prank(alice);
        nft.purchase("alice");
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 2);
        vm.expectEmit(true, true, false, false);
        emit Purchase(alice, "alice's plus one");
        nft.purchase("alice's plus one");
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.holderOf(2), alice);
        assertEq(nft.getApproved(2), address(0));
        assertEq(nft.holderNameOf(2), "alice's plus one");
        assertEq(nft.isExpiredOrUsed(2), false);
    }
}

// Use vm.warp to jump forward when testing expired tickets
contract SecondaryMarketTest is BaseTicketNFTTest {
    function testList() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, address(nft), 1);
        vm.expectEmit(true, true, true, false);
        emit Approval(address(nft), address(0), 1);
        vm.expectEmit(true, true, false, false);
        emit Listing(1, alice, 200e18);
        nft.listTicket(1, 200e18); // Got a flipper here :)
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(address(nft)), 1);
        assertEq(nft.holderOf(1), address(nft));
        assertEq(nft.getApproved(1), address(0));
        assertEq(nft.holderNameOf(1), "alice");
        assertEq(nft.isExpiredOrUsed(1), false);
    }

    function testListFree() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        vm.expectRevert("listTicket: price cannot be 0");
        nft.listTicket(1, 0); // What's the opposite of a flipper?
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.holderOf(1), alice);
    }

    function testListUsed() public {
        _buyTicket(alice, "alice");
        vm.prank(address(this));
        nft.setUsed(1);
        vm.prank(alice);
        vm.expectRevert("listTicket: ticket is expired/used");
        nft.listTicket(1, 200e19);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.holderOf(1), alice);
        assertEq(nft.isExpiredOrUsed(1), true);
    }

    function testListExpired() public {
        _buyTicket(alice, "alice");
        vm.warp(block.timestamp + 10 days);
        vm.prank(alice);
        vm.expectRevert("listTicket: ticket is expired/used");
        nft.listTicket(1, 200e19);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.holderOf(1), alice);
        assertEq(nft.isExpiredOrUsed(1), true);
    }

    function testListUnauthorized() public {
        _buyTicket(alice, "alice");
        vm.prank(bob);
        vm.expectRevert("listTicket: msg.sender doesn't own ticket");
        nft.listTicket(1, 200e19);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.holderOf(1), alice);
    }

    function testDelist() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, 200e18);
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(nft), alice, 1);
        vm.expectEmit(true, true, true, false);
        emit Approval(alice, address(0), 1);
        vm.expectEmit(true, false, false, false);
        emit Delisting(1);
        nft.delistTicket(1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(address(nft)), 0);
        assertEq(nft.holderOf(1), alice);
    }

    function testDelistUnauthorized() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, 200e18);
        vm.prank(bob);
        vm.expectRevert("delistTicket: msg.sender didn't list ticket");
        nft.delistTicket(1);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(address(nft)), 1);
        assertEq(nft.holderOf(1), address(nft));
    }

    function testPurchase() public {
        uint256 ticketResalePrice = 200e18;
        uint256 ticketResaleFee = 25 * (ticketResalePrice / 1000);
        uint256 ticketResaleRevenue = ticketResalePrice - ticketResaleFee;
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, ticketResalePrice);
        _topUpTokens(bob, ticketResalePrice / 100e18);
        vm.prank(bob);
        token.approve(address(nft), ticketResalePrice);
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Purchase(bob, 1, ticketResalePrice, "bob");
        nft.purchase(1, "bob");
        assertEq(token.balanceOf(alice), ticketResaleRevenue);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), ticketPrice + ticketResaleFee);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.balanceOf(address(nft)), 0);
        assertEq(nft.holderOf(1), bob);
        assertEq(nft.getApproved(1), address(0));
        assertEq(nft.holderNameOf(1), "bob");
        assertEq(nft.isExpiredOrUsed(1), false);
    }

    function testPurchaseUsed() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, 200e18);
        _topUpTokens(bob, 2);
        vm.prank(address(this));
        nft.setUsed(1);
        vm.prank(bob);
        token.approve(address(nft), 200e18);
        vm.prank(bob);
        vm.expectRevert("purchase: ticket is expired/used");
        nft.purchase(1, "bob");
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(address(nft)), 1);
    }

    function testPurchaseExpired() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, 200e18);
        _topUpTokens(bob, 2);
        vm.warp(block.timestamp + 10 days);
        vm.prank(bob);
        token.approve(address(nft), 200e18);
        vm.prank(bob);
        vm.expectRevert("purchase: ticket is expired/used");
        nft.purchase(1, "bob");
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(address(nft)), 1);
    }

    function testPurchaseInsufficientBalance() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, 200e18);
        _topUpTokens(bob, 1);
        vm.prank(bob);
        token.approve(address(nft), 200e18);
        vm.prank(bob);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        nft.purchase(1, "bob");
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(address(nft)), 1);
    }

    function testPurchaseInsufficientAllowance() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, 200e18);
        _topUpTokens(bob, 2);
        vm.prank(bob);
        token.approve(address(nft), 100e18);
        vm.prank(bob);
        vm.expectRevert("purchase: insufficient token allowance");
        nft.purchase(1, "bob");
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(address(nft)), 1);
    }

    function testPurchaseUnlisted() public {
        _buyTicket(alice, "alice");
        vm.prank(alice);
        nft.listTicket(1, 200e18);
        vm.prank(alice);
        nft.delistTicket(1);
        _topUpTokens(bob, 2);
        vm.prank(bob);
        token.approve(address(nft), 200e18);
        vm.prank(bob);
        vm.expectRevert(
            "purchase: ticket is not listed, missing lister address or price"
        );
        nft.purchase(1, "bob");
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(address(nft)), 0);
    }
}
