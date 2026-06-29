// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC7575} from "./interfaces/IERC7575.sol";
import {IERC7575Errors} from "./interfaces/IERC7575Errors.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {SafeTokenTransfers} from "./SafeTokenTransfers.sol";

contract Vault is IERC7575, ERC165, Ownable, Pausable, IERC7575Errors {
    event RedeemApproval(address indexed owner, address indexed spender, uint256 shares);
    event VaultActiveStateChanged(bool indexed isActive);

    address private immutable _asset;
    address private immutable _shareToken;
    uint8 private immutable _assetDecimals;
    uint256 private immutable _scalingFactor;
    bool private _isActive;
    mapping(address => mapping(address => uint256)) public shareAllowance;

    constructor(address asset_, address shareToken_) Ownable(msg.sender) {
        if (shareToken_ == address(0)) revert ZeroAddress();
        _asset = asset_;
        _shareToken = shareToken_;
        _assetDecimals = IERC20Metadata(asset_).decimals();
        if (_assetDecimals > 18) revert UnsupportedAssetDecimals();
        _scalingFactor = 10 ** (18 - _assetDecimals);
        _isActive = true;
    }

    function asset() external view returns (address) {
        return _asset;
    }

    function share() external view returns (address) {
        return _shareToken;
    }

    function isVaultActive() external view returns (bool) {
        return _isActive;
    }

    function setVaultActive(bool active) external onlyOwner {
        _isActive = active;
        emit VaultActiveStateChanged(active);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC7575).interfaceId || super.supportsInterface(interfaceId);
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

    function deposit(uint256 assets, address receiver) external whenNotPaused returns (uint256 shares) {
        if (!_isActive) revert VaultNotActive();
        if (receiver == address(0)) revert InvalidReceiver();
        if (assets == 0) revert ZeroAssets();

        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        SafeTokenTransfers.safeTransferFrom(_asset, msg.sender, address(this), assets);

        IShareToken(_shareToken).mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external whenNotPaused returns (uint256 assets) {
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

        uint256 currentShares = IERC20(_shareToken).balanceOf(owner);
        if (currentShares < shares) revert InsufficientShares();

        IShareToken(_shareToken).burn(owner, shares);

        SafeTokenTransfers.safeTransfer(_asset, receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
