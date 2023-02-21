// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";

contract PurchaseTokenTest is Test {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    PurchaseToken public token;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        token = new PurchaseToken();
    }

    function testName() public {
        assertEq(token.name(), "PurchaseToken");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "PT");
    }

    function testAllowance() public {
        assertEq(token.allowance(alice, bob), 0);
    }

    function testBalanceOf() public {
        assertEq(token.balanceOf(alice), 0);
    }

    function testDecimals() public {
        assertEq(token.decimals(), 18);
    }

    function testTotalSupply() public {
        assertEq(token.totalSupply(), 0);
    }

    function testMint() public {
        vm.deal(alice, 1 ether);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1e19);
        token.mint{value: 1e17}();
        assertEq(token.balanceOf(alice), 1e19);
        assertEq(token.totalSupply(), 1e19);
    }

    function testMintInvalid() public {
        vm.prank(address(0));
        vm.expectRevert("ERC20: mint to the zero address");
        token.mint();
    }

    function testMintInsufficientFunds() public {
        vm.deal(alice, 0.01 ether);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
        vm.prank(alice);
        vm.expectRevert();
        token.mint{value: 1e17}();
    }

    function testTransfer() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        token.mint{value: 1e17}();
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 1e18);
        token.transfer(bob, 1e18);
        assertEq(token.balanceOf(alice), 9e18);
        assertEq(token.balanceOf(bob), 1e18);
    }

    function testTransferInsufficientFunds() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        token.mint{value: 1e17}();
        vm.prank(alice);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(bob, 2e19);
    }

    function testApprove() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 1e18);
        token.approve(bob, 1e18);
        assertEq(token.allowance(alice, bob), 1e18);
    }

    function testTransferFrom() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1e19);
        token.mint{value: 1e17}();
        vm.prank(alice);
        token.approve(bob, 3e18);
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, charlie, 1e18);
        token.transferFrom(alice, charlie, 1e18);
        assertEq(token.balanceOf(alice), 9e18);
        assertEq(token.allowance(alice, bob), 2e18);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(charlie), 1e18);
    }

    function testTransferFromInsufficientAllowance() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1e19);
        token.mint{value: 1e17}();
        vm.prank(alice);
        token.approve(bob, 3e18);
        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        token.transferFrom(alice, charlie, 4e18);
    }
}
