// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ShareToken} from "../src/ShareToken.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC7575Errors} from "../src/interfaces/IERC7575Errors.sol";

/// @notice Boundary reverts, rounding edges, and fuzz checks for preview/execution parity.
contract EdgeCasesTest is Test {
    ShareToken internal shareToken;
    ShareToken internal shareToken6;
    Vault internal vault;
    Vault internal vault6;
    MockERC20 internal usdc;
    MockERC20 internal usdc6;

    address internal user = makeAddr("user");
    address internal receiver = makeAddr("receiver");
    address internal operator = makeAddr("operator");

    uint256 internal constant AMOUNT = 100e18;
    uint256 internal constant ONE_USDC_6 = 1e6;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "mUSDC", 18);
        usdc6 = new MockERC20("USDC", "USDC", 6);

        shareToken = new ShareToken();
        vault = new Vault(address(usdc), address(shareToken));
        shareToken.registerVault(address(usdc), address(vault));

        shareToken6 = new ShareToken();
        vault6 = new Vault(address(usdc6), address(shareToken6));
        shareToken6.registerVault(address(usdc6), address(vault6));

        usdc.mint(user, 1_000e18);
        usdc6.mint(user, 10_000e6);

        vm.startPrank(user);
        usdc.approve(address(vault), type(uint256).max);
        usdc6.approve(address(vault6), type(uint256).max);
        vm.stopPrank();
    }

    // --- deposit boundaries ---

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

    function testApproveRedeemerZeroSpenderReverts() public {
        vm.prank(user);
        vm.expectRevert(IERC7575Errors.InvalidReceiver.selector);
        vault.approveRedeemer(address(0), AMOUNT);
    }

    // --- redeem boundaries ---

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

    function testRedeemInsufficientSharesReverts() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(user);
        vm.expectRevert(IERC7575Errors.InsufficientShares.selector);
        vault.redeem(AMOUNT + 1, user, user);
    }

    function testRedeemUnauthorizedOperatorReverts() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(operator);
        vm.expectRevert(IERC7575Errors.InsufficientAllowance.selector);
        vault.redeem(AMOUNT, receiver, user);
    }

    // --- 6-decimal rounding: shares below scaling factor redeem to zero assets ---

    function testRedeem6DecimalsDustSharesRevertsZeroAssets() public {
        vm.prank(user);
        vault6.deposit(ONE_USDC_6, user);

        // 1 share < 10^12 scaling factor => convertToAssets returns 0
        vm.prank(user);
        vm.expectRevert(IERC7575Errors.ZeroAssets.selector);
        vault6.redeem(1, user, user);
    }

    function testUnsupportedAssetDecimalsRevertsOnDeploy() public {
        MockERC20 exotic = new MockERC20("Exotic", "EXO", 19);
        ShareToken token = new ShareToken();
        vm.expectRevert(IERC7575Errors.UnsupportedAssetDecimals.selector);
        new Vault(address(exotic), address(token));
    }

    function testZeroShareTokenRevertsOnDeploy() public {
        vm.expectRevert(IERC7575Errors.ZeroAddress.selector);
        new Vault(address(usdc), address(0));
    }

    // --- fuzz: preview must match execution ---

    function testFuzz_depositPreviewMatchesExecution(uint256 assets) public {
        assets = bound(assets, 1, 500e18);

        uint256 expectedShares = vault.previewDeposit(assets);

        vm.prank(user);
        uint256 actualShares = vault.deposit(assets, user);

        assertEq(actualShares, expectedShares);
        assertEq(shareToken.balanceOf(user), expectedShares);
    }

    function testFuzz_depositPreviewMatchesExecution6Decimals(uint256 assets) public {
        assets = bound(assets, 1, 5_000e6);

        uint256 expectedShares = vault6.previewDeposit(assets);

        vm.prank(user);
        uint256 actualShares = vault6.deposit(assets, user);

        assertEq(actualShares, expectedShares);
    }

    function testFuzz_redeemPreviewMatchesExecution(uint256 assets) public {
        assets = bound(assets, 1, 500e18);

        vm.prank(user);
        uint256 shares = vault.deposit(assets, user);

        uint256 expectedAssets = vault.previewRedeem(shares);

        vm.prank(user);
        uint256 actualAssets = vault.redeem(shares, user, user);

        assertEq(actualAssets, expectedAssets);
        assertEq(usdc.balanceOf(user), 1_000e18);
    }
}
