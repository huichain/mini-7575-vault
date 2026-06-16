// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IERC7575} from "../src/interfaces/IERC7575.sol";
import {IERC7575Errors} from "../src/interfaces/IERC7575Errors.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract VaultControlsTest is Test {
    event VaultActiveStateChanged(bool indexed isActive);

    Vault internal vault;
    MockERC20 internal usdc;

    address internal user = makeAddr("user");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant AMOUNT = 100e18;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "mUSDC", 18);
        vault = new Vault(address(usdc));

        usdc.mint(user, 1_000e18);
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testIsVaultActiveByDefault() public view {
        assertTrue(vault.isVaultActive());
    }

    function testSetVaultActiveEmitsAndUpdatesState() public {
        vm.expectEmit(true, false, false, true, address(vault));
        emit VaultActiveStateChanged(false);
        vault.setVaultActive(false);
        assertFalse(vault.isVaultActive());

        vm.expectEmit(true, false, false, true, address(vault));
        emit VaultActiveStateChanged(true);
        vault.setVaultActive(true);
        assertTrue(vault.isVaultActive());
    }

    function testSetVaultActiveRevertsForNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vault.setVaultActive(false);
    }

    function testInactiveVaultBlocksDeposit() public {
        vault.setVaultActive(false);

        vm.prank(user);
        vm.expectRevert(IERC7575Errors.VaultNotActive.selector);
        vault.deposit(AMOUNT, user);
    }

    function testInactiveVaultAllowsRedeem() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vault.setVaultActive(false);

        vm.prank(user);
        uint256 assetsOut = vault.redeem(AMOUNT, user, user);
        assertEq(assetsOut, AMOUNT);
    }

    function testPauseBlocksDeposit() public {
        vault.pause();

        vm.prank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.deposit(AMOUNT, user);
    }

    function testPauseBlocksRedeem() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vault.pause();

        vm.prank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.redeem(AMOUNT, user, user);
    }

    function testUnpauseRestoresDepositAndRedeem() public {
        vault.pause();
        vault.unpause();

        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(user);
        assertEq(vault.redeem(AMOUNT, user, user), AMOUNT);
    }

    function testPauseRevertsForNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vault.pause();
    }

    function testSupportsIERC7575Interface() public view {
        assertTrue(vault.supportsInterface(type(IERC7575).interfaceId));
    }

    function testSupportsIERC165Interface() public view {
        assertTrue(vault.supportsInterface(type(IERC165).interfaceId));
    }

    function testDoesNotSupportUnknownInterface() public view {
        assertFalse(vault.supportsInterface(bytes4(0xdeadbeef)));
    }
}
