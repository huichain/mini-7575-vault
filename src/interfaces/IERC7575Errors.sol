// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC7575Errors {
    error ZeroAssets();
    error ZeroShares();
    error InvalidReceiver();
    error InvalidOwner();
    error InsufficientShares();
    error InsufficientAllowance();
    error Unauthorized();
}
