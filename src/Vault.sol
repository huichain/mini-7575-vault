// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7575} from "./interfaces/IERC7575.sol";
import {IERC7575Errors} from "./interfaces/IERC7575Errors.sol";

contract Vault is IERC7575, IERC7575Errors {
    address private immutable _asset;
    mapping(address => uint256) public shareBalance;
    uint256 public totalShareSupply;

    constructor(address asset_) {
        _asset = asset_;
    }

    function asset() external view returns (address) {
        return _asset;
    }

    function totalAssets() public view returns (uint256) {
        return IERC20(_asset).balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public pure returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) public pure returns (uint256) {
        return shares;
    }

    function previewDeposit(uint256 assets) public pure returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public pure returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (assets == 0) revert ZeroAssets();

        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        bool ok = IERC20(_asset).transferFrom(msg.sender, address(this), assets);
        require(ok, "TRANSFER_FROM_FAILED");

        shareBalance[receiver] += shares;
        totalShareSupply += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (owner == address(0)) revert InvalidOwner();
        if (owner != msg.sender) revert Unauthorized();
        if (shares == 0) revert ZeroShares();

        assets = previewRedeem(shares);
        if (assets == 0) revert ZeroAssets();

        uint256 currentShares = shareBalance[owner];
        if (currentShares < shares) revert InsufficientShares();

        shareBalance[owner] = currentShares - shares;
        totalShareSupply -= shares;

        bool ok = IERC20(_asset).transfer(receiver, assets);
        require(ok, "TRANSFER_FAILED");

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
