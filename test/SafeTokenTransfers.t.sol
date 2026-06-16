// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {SafeTokenTransfers} from "../src/SafeTokenTransfers.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockFeeOnTransferERC20} from "../src/mocks/MockFeeOnTransferERC20.sol";

/// @notice Minimal consumer contract so the internal library can be unit-tested like Vault does.
contract SafeTokenTransfersHarness {
    /// @dev Mirrors deposit: pull assets from `from` into this contract.
    function pull(address token, address from, uint256 amount) external {
        SafeTokenTransfers.safeTransferFrom(token, from, address(this), amount);
    }

    /// @dev Mirrors redeem: push assets from this contract to `to`.
    function push(address token, address to, uint256 amount) external {
        SafeTokenTransfers.safeTransfer(token, to, amount);
    }
}

/// @notice Tests balance-checked transfers: standard ERC20 passes, fee-on-transfer reverts.
contract SafeTokenTransfersTest is Test {
    SafeTokenTransfersHarness internal harness;
    MockERC20 internal token;
    MockFeeOnTransferERC20 internal feeToken;

    address internal user = makeAddr("user");
    address internal receiver = makeAddr("receiver");

    uint256 internal constant AMOUNT = 100e18;

    function setUp() public {
        harness = new SafeTokenTransfersHarness();
        token = new MockERC20("Mock USDC", "mUSDC", 18);
        feeToken = new MockFeeOnTransferERC20("Fee Token", "FEE", 18);

        // pull spends user balance; push spends harness balance — mint both sides for each token.
        token.mint(user, 1_000e18);
        token.mint(address(harness), 1_000e18);
        feeToken.mint(user, 1_000e18);
        feeToken.mint(address(harness), 1_000e18);

        vm.prank(user);
        token.approve(address(harness), type(uint256).max);
        vm.prank(user);
        feeToken.approve(address(harness), type(uint256).max);
    }

    function testSafeTransferFromSucceedsWithStandardToken() public {
        uint256 balanceBefore = token.balanceOf(address(harness));
        harness.pull(address(token), user, AMOUNT);
        assertEq(token.balanceOf(address(harness)), balanceBefore + AMOUNT);
    }

    function testSafeTransferSucceedsWithStandardToken() public {
        harness.push(address(token), receiver, AMOUNT);
        assertEq(token.balanceOf(receiver), AMOUNT);
    }

    function testSafeTransferFromRevertsOnFeeOnTransferToken() public {
        vm.prank(user);
        vm.expectRevert(SafeTokenTransfers.TransferAmountMismatch.selector);
        harness.pull(address(feeToken), user, AMOUNT);
    }

    function testSafeTransferRevertsOnFeeOnTransferToken() public {
        vm.expectRevert(SafeTokenTransfers.TransferAmountMismatch.selector);
        harness.push(address(feeToken), receiver, AMOUNT);
    }

    function testVaultDepositRevertsOnFeeOnTransferToken() public {
        Vault vault = new Vault(address(feeToken));

        vm.prank(user);
        feeToken.approve(address(vault), type(uint256).max);

        vm.prank(user);
        vm.expectRevert(SafeTokenTransfers.TransferAmountMismatch.selector);
        vault.deposit(AMOUNT, user);
    }

    function testVaultRedeemStillSucceedsWithStandardToken() public {
        Vault vault = new Vault(address(token));

        vm.prank(user);
        token.approve(address(vault), type(uint256).max);

        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.prank(user);
        uint256 assetsOut = vault.redeem(AMOUNT, user, user);

        assertEq(assetsOut, AMOUNT);
        assertEq(token.balanceOf(user), 1_000e18);
    }
}
