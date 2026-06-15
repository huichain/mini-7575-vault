// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC7575Errors} from "../src/interfaces/IERC7575Errors.sol";

contract VaultTest is Test {
    Vault internal vault;
    MockERC20 internal usdc;

    address internal user = makeAddr("user");
    address internal receiver = makeAddr("receiver");
    address internal operator = makeAddr("operator");

    uint256 internal constant AMOUNT = 100e18;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "mUSDC", 18);
        vault = new Vault(address(usdc));

        usdc.mint(user, 1_000e18);
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testPreviewDepositZeroAssets() public view {
        assertEq(vault.previewDeposit(0), 0);
    }

    function testDepositZeroAddressReceiverReverts() public {
        vm.prank(user);
        vm.expectRevert(IERC7575Errors.InvalidReceiver.selector);
        vault.deposit(AMOUNT, address(0));
    }

    function testDepositZeroAssetsReverts() public {
        vm.prank(user);
        vm.expectRevert(IERC7575Errors.ZeroAssets.selector);
        vault.deposit(0, user);
    }

    function testDepositMintsExpectedShares() public {
        vm.prank(user);
        uint256 mintedShares = vault.deposit(AMOUNT, receiver);

        assertEq(mintedShares, AMOUNT);
        assertEq(vault.shareBalance(receiver), AMOUNT);
        assertEq(vault.totalAssets(), AMOUNT);
    }

    function testPreviewMatchesDeposit() public {
        uint256 expectedShares = vault.previewDeposit(AMOUNT);

        vm.prank(user);
        uint256 actualShares = vault.deposit(AMOUNT, user);

        assertEq(actualShares, expectedShares);
    }

    function testRedeemEndToEnd() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        uint256 previewAssets = vault.previewRedeem(AMOUNT);
        assertEq(previewAssets, AMOUNT);

        vm.prank(user);
        uint256 assetsOut = vault.redeem(AMOUNT, user, user);

        assertEq(assetsOut, AMOUNT);
        assertEq(vault.shareBalance(user), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(usdc.balanceOf(user), 1_000e18);
    }

    function testRedeemInvalidOwnerReverts() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(user);
        vm.expectRevert(IERC7575Errors.InvalidOwner.selector);
        vault.redeem(AMOUNT, user, address(0));
    }

    function testRedeemInvalidReceiverReverts() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(user);
        vm.expectRevert(IERC7575Errors.InvalidReceiver.selector);
        vault.redeem(AMOUNT, address(0), user);
    }

    function testRedeemZeroSharesReverts() public {
        vm.prank(user);
        vm.expectRevert(IERC7575Errors.ZeroShares.selector);
        vault.redeem(0, user, user);
    }

    function testRedeemUnauthorizedOperatorReverts() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(operator);
        vm.expectRevert(IERC7575Errors.InsufficientAllowance.selector);
        vault.redeem(AMOUNT, receiver, user);
    }

    function testRedeemAuthorizedOperatorSucceeds() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(user);
        assertTrue(vault.approveRedeemer(operator, AMOUNT));

        vm.prank(operator);
        uint256 assetsOut = vault.redeem(AMOUNT, receiver, user);

        assertEq(assetsOut, AMOUNT);
        assertEq(vault.shareBalance(user), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(usdc.balanceOf(receiver), AMOUNT);
    }

    function testRedeemAuthorizedOperatorAllowanceDecreases() public {
        uint256 depositAmount = 200e18;
        uint256 redeemAmount = 60e18;

        vm.prank(user);
        vault.deposit(depositAmount, user);

        vm.prank(user);
        assertTrue(vault.approveRedeemer(operator, AMOUNT));

        vm.prank(operator);
        vault.redeem(redeemAmount, receiver, user);

        assertEq(vault.shareAllowance(user, operator), AMOUNT - redeemAmount);
        assertEq(vault.shareBalance(user), depositAmount - redeemAmount);
    }
}
