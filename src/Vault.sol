// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC7575} from "./interfaces/IERC7575.sol";
import {IERC7575Errors} from "./interfaces/IERC7575Errors.sol";
import {SafeTokenTransfers} from "./SafeTokenTransfers.sol";

contract Vault is IERC7575, IERC7575Errors {
    event RedeemApproval(address indexed owner, address indexed spender, uint256 shares);

    address private immutable _asset;
    uint8 private immutable _assetDecimals;
    uint256 private immutable _scalingFactor;
    mapping(address => uint256) public shareBalance;
    mapping(address => mapping(address => uint256)) public shareAllowance;
    uint256 public totalShareSupply;

    constructor(address asset_) {
        _asset = asset_;
        _assetDecimals = IERC20Metadata(asset_).decimals();
        if (_assetDecimals > 18) revert UnsupportedAssetDecimals();
        _scalingFactor = 10 ** (18 - _assetDecimals);
    }

    function asset() external view returns (address) {
        return _asset;
    }

    function totalAssets() public view returns (uint256) {
        return IERC20(_asset).balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets * _scalingFactor;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares / _scalingFactor;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function approveRedeemer(address spender, uint256 shares) external returns (bool) {
        if (spender == address(0)) revert InvalidReceiver();
        shareAllowance[msg.sender][spender] = shares;
        emit RedeemApproval(msg.sender, spender, shares);
        return true;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (assets == 0) revert ZeroAssets();

        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        SafeTokenTransfers.safeTransferFrom(_asset, msg.sender, address(this), assets);

        shareBalance[receiver] += shares;
        totalShareSupply += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (owner == address(0)) revert InvalidOwner();
        if (owner != msg.sender) {
            uint256 allowed = shareAllowance[owner][msg.sender];
            if (allowed < shares) revert InsufficientAllowance();
            if (allowed != type(uint256).max) {
                shareAllowance[owner][msg.sender] = allowed - shares;
            }
        }
        if (shares == 0) revert ZeroShares();

        assets = previewRedeem(shares);
        if (assets == 0) revert ZeroAssets();

        uint256 currentShares = shareBalance[owner];
        if (currentShares < shares) revert InsufficientShares();

        shareBalance[owner] = currentShares - shares;
        totalShareSupply -= shares;

        SafeTokenTransfers.safeTransfer(_asset, receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
