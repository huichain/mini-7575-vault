// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Balance-checked ERC20 transfers that reject fee-on-transfer style accounting drift.
library SafeTokenTransfers {
    using SafeERC20 for IERC20Metadata;

    error TransferAmountMismatch();

    function safeTransfer(address token, address recipient, uint256 amount) internal {
        uint256 balanceBefore = IERC20Metadata(token).balanceOf(recipient);
        IERC20Metadata(token).safeTransfer(recipient, amount);
        uint256 balanceAfter = IERC20Metadata(token).balanceOf(recipient);
        if (balanceAfter != balanceBefore + amount) revert TransferAmountMismatch();
    }

    function safeTransferFrom(address token, address sender, address recipient, uint256 amount) internal {
        uint256 balanceBefore = IERC20Metadata(token).balanceOf(recipient);
        IERC20Metadata(token).safeTransferFrom(sender, recipient, amount);
        uint256 balanceAfter = IERC20Metadata(token).balanceOf(recipient);
        if (balanceAfter != balanceBefore + amount) revert TransferAmountMismatch();
    }
}
