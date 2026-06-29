// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC7575} from "./interfaces/IERC7575.sol";
import {IERC7575Errors} from "./interfaces/IERC7575Errors.sol";

/// @notice 18-decimal share token shared across ERC-7575 vaults.
contract ShareToken is ERC20, Ownable, IERC7575Errors {
    event VaultRegistered(address indexed asset, address indexed vault);
    event VaultUnregistered(address indexed asset, address indexed vault);

    mapping(address asset => address vault) private _assetToVault;
    mapping(address vault => address asset) private _vaultToAsset;

    /// @dev Enumerable set of registered vaults backing cross-vault aggregation.
    address[] private _vaults;
    mapping(address vault => uint256 index) private _vaultIndex;

    constructor() ERC20("7575 Share", "s7575") Ownable(msg.sender) {}

    modifier onlyVault() {
        if (_vaultToAsset[msg.sender] == address(0)) revert Unauthorized();
        _;
    }

    /// @notice Register a vault for the given asset after deployment-time wiring checks.
    function registerVault(address asset, address vaultAddress) external onlyOwner {
        if (asset == address(0) || vaultAddress == address(0)) revert ZeroAddress();
        if (_assetToVault[asset] != address(0)) revert AssetAlreadyRegistered();
        if (IERC7575(vaultAddress).asset() != asset) revert AssetMismatch();
        if (IERC7575(vaultAddress).share() != address(this)) revert VaultShareMismatch();

        _assetToVault[asset] = vaultAddress;
        _vaultToAsset[vaultAddress] = asset;
        _vaultIndex[vaultAddress] = _vaults.length;
        _vaults.push(vaultAddress);

        emit VaultRegistered(asset, vaultAddress);
    }

    /// @notice Remove a vault from the registry, allowed only when it holds no assets.
    function unregisterVault(address asset) external onlyOwner {
        address vaultAddress = _assetToVault[asset];
        if (vaultAddress == address(0)) revert AssetNotRegistered();
        if (IERC7575(vaultAddress).totalAssets() != 0) revert VaultNotEmpty();

        uint256 index = _vaultIndex[vaultAddress];
        uint256 lastIndex = _vaults.length - 1;
        if (index != lastIndex) {
            address lastVault = _vaults[lastIndex];
            _vaults[index] = lastVault;
            _vaultIndex[lastVault] = index;
        }
        _vaults.pop();

        delete _vaultIndex[vaultAddress];
        delete _assetToVault[asset];
        delete _vaultToAsset[vaultAddress];

        emit VaultUnregistered(asset, vaultAddress);
    }

    function vaultForAsset(address asset) external view returns (address) {
        return _assetToVault[asset];
    }

    function isVault(address vaultAddress) external view returns (bool) {
        return _vaultToAsset[vaultAddress] != address(0);
    }

    function vaultCount() external view returns (uint256) {
        return _vaults.length;
    }

    function vaultAt(uint256 index) external view returns (address) {
        return _vaults[index];
    }

    /// @notice Sum each registered vault's asset balance normalized to 18 decimals.
    function getTotalNormalizedAssets() external view returns (uint256 total) {
        uint256 length = _vaults.length;
        for (uint256 i = 0; i < length; ++i) {
            IERC7575 vault = IERC7575(_vaults[i]);
            total += vault.convertToShares(vault.totalAssets());
        }
    }

    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }
}
