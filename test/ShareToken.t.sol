// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ShareToken} from "../src/ShareToken.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC7575Errors} from "../src/interfaces/IERC7575Errors.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice ShareToken registry and vault integration tests.
contract ShareTokenTest is Test {
    ShareToken internal shareToken;
    Vault internal vault;
    MockERC20 internal usdc;

    address internal user = makeAddr("user");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant AMOUNT = 100e18;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "mUSDC", 18);
        shareToken = new ShareToken();
        vault = new Vault(address(usdc), address(shareToken));

        usdc.mint(user, 1_000e18);
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testRegisterVaultSucceeds() public {
        shareToken.registerVault(address(usdc), address(vault));

        assertTrue(shareToken.isVault(address(vault)));
        assertEq(shareToken.vaultForAsset(address(usdc)), address(vault));
        assertEq(vault.share(), address(shareToken));
    }

    function testRegisterVaultDuplicateReverts() public {
        shareToken.registerVault(address(usdc), address(vault));

        vm.expectRevert(IERC7575Errors.AssetAlreadyRegistered.selector);
        shareToken.registerVault(address(usdc), address(vault));
    }

    function testRegisterVaultAssetMismatchReverts() public {
        MockERC20 other = new MockERC20("Other", "OTH", 18);
        Vault otherVault = new Vault(address(other), address(shareToken));

        vm.expectRevert(IERC7575Errors.AssetMismatch.selector);
        shareToken.registerVault(address(usdc), address(otherVault));
    }

    function testRegisterVaultShareMismatchReverts() public {
        ShareToken otherShare = new ShareToken();
        Vault mismatched = new Vault(address(usdc), address(otherShare));

        vm.expectRevert(IERC7575Errors.VaultShareMismatch.selector);
        shareToken.registerVault(address(usdc), address(mismatched));
    }

    function testRegisterVaultRevertsForNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        shareToken.registerVault(address(usdc), address(vault));
    }

    function testDepositMintsShareTokenBalance() public {
        shareToken.registerVault(address(usdc), address(vault));

        vm.prank(user);
        vault.deposit(AMOUNT, user);

        assertEq(shareToken.balanceOf(user), AMOUNT);
        assertEq(shareToken.totalSupply(), AMOUNT);
    }

    function testRedeemBurnsShareTokenBalance() public {
        shareToken.registerVault(address(usdc), address(vault));

        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(user);
        vault.redeem(AMOUNT, user, user);

        assertEq(shareToken.balanceOf(user), 0);
        assertEq(shareToken.totalSupply(), 0);
    }

    function testMintFromUnregisteredVaultReverts() public {
        vm.prank(address(vault));
        vm.expectRevert(IERC7575Errors.Unauthorized.selector);
        shareToken.mint(user, AMOUNT);
    }

    function testUnregisterVaultSucceedsWhenEmpty() public {
        shareToken.registerVault(address(usdc), address(vault));
        assertEq(shareToken.vaultCount(), 1);

        shareToken.unregisterVault(address(usdc));

        assertFalse(shareToken.isVault(address(vault)));
        assertEq(shareToken.vaultForAsset(address(usdc)), address(0));
        assertEq(shareToken.vaultCount(), 0);
    }

    function testUnregisterVaultRevertsWhenNotRegistered() public {
        vm.expectRevert(IERC7575Errors.AssetNotRegistered.selector);
        shareToken.unregisterVault(address(usdc));
    }

    function testUnregisterVaultRevertsForNonOwner() public {
        shareToken.registerVault(address(usdc), address(vault));

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        shareToken.unregisterVault(address(usdc));
    }

    function testUnregisterVaultRevertsWhenNotEmpty() public {
        shareToken.registerVault(address(usdc), address(vault));

        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.expectRevert(IERC7575Errors.VaultNotEmpty.selector);
        shareToken.unregisterVault(address(usdc));
    }

    function testUnregisterVaultKeepsRemainingRegistryConsistent() public {
        MockERC20 dai = new MockERC20("Mock DAI", "mDAI", 18);
        Vault daiVault = new Vault(address(dai), address(shareToken));

        shareToken.registerVault(address(usdc), address(vault));
        shareToken.registerVault(address(dai), address(daiVault));
        assertEq(shareToken.vaultCount(), 2);

        // Remove the first vault; the swap-and-pop should keep the second intact.
        shareToken.unregisterVault(address(usdc));

        assertEq(shareToken.vaultCount(), 1);
        assertEq(shareToken.vaultAt(0), address(daiVault));
        assertTrue(shareToken.isVault(address(daiVault)));
        assertFalse(shareToken.isVault(address(vault)));
    }

    function testGetTotalNormalizedAssetsAggregatesAcrossDecimals() public {
        MockERC20 usdt = new MockERC20("Mock USDT", "mUSDT", 6);
        Vault usdtVault = new Vault(address(usdt), address(shareToken));

        shareToken.registerVault(address(usdc), address(vault));
        shareToken.registerVault(address(usdt), address(usdtVault));

        usdt.mint(user, 1_000e6);
        vm.startPrank(user);
        usdt.approve(address(usdtVault), type(uint256).max);
        vault.deposit(AMOUNT, user); // 100e18 (18-decimal asset)
        usdtVault.deposit(50e6, user); // 50 USDT normalized to 50e18
        vm.stopPrank();

        assertEq(shareToken.getTotalNormalizedAssets(), AMOUNT + 50e18);
    }

    function testGetTotalNormalizedAssetsIsZeroWithNoVaults() public view {
        assertEq(shareToken.getTotalNormalizedAssets(), 0);
    }
}
