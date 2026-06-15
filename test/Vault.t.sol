// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC7575Errors} from "../src/interfaces/IERC7575Errors.sol";

/// @notice Tests for Vault deposit/redeem, preview parity, operator allowance, and decimal scaling.
contract VaultTest is Test {
    Vault internal vault;
    MockERC20 internal usdc;

    address internal user = makeAddr("user");
    address internal receiver = makeAddr("receiver");
    address internal operator = makeAddr("operator");

    uint256 internal constant AMOUNT = 100e18;
    uint256 internal constant ONE_USDC_6_DECIMALS = 1e6; // 1 whole USDC (6 decimals)

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

    function testConvertToShares18DecimalsIsOneToOne() public view {
        assertEq(vault.convertToShares(1e18), 1e18);
    }

    // Vault shares are always 18 decimals; 6-decimal assets scale up by 10^12.
    function testConvertToShares6DecimalsNormalizesTo18() public {
        MockERC20 usdc6 = new MockERC20("USDC", "USDC", 6);
        Vault vault6 = new Vault(address(usdc6));

        assertEq(vault6.convertToShares(ONE_USDC_6_DECIMALS), 1e18);
    }

    function testDepositAndRedeem6DecimalsRoundTrip() public {
        MockERC20 usdc6 = new MockERC20("USDC", "USDC", 6);
        Vault vault6 = new Vault(address(usdc6));

        usdc6.mint(user, 10_000e6);
        vm.prank(user);
        usdc6.approve(address(vault6), type(uint256).max);

        vm.prank(user);
        uint256 shares = vault6.deposit(ONE_USDC_6_DECIMALS, user);
        assertEq(shares, 1e18);
        assertEq(vault6.shareBalance(user), 1e18);

        vm.prank(user);
        uint256 assetsOut = vault6.redeem(1e18, user, user);
        assertEq(assetsOut, ONE_USDC_6_DECIMALS);
    }

    function testPreviewMatchesDepositFor6Decimals() public {
        MockERC20 usdc6 = new MockERC20("USDC", "USDC", 6);
        Vault vault6 = new Vault(address(usdc6));

        usdc6.mint(user, 10_000e6);
        vm.prank(user);
        usdc6.approve(address(vault6), type(uint256).max);

        uint256 expectedShares = vault6.previewDeposit(2e6);
        vm.prank(user);
        uint256 actualShares = vault6.deposit(2e6, user);

        assertEq(actualShares, expectedShares);
    }
}
