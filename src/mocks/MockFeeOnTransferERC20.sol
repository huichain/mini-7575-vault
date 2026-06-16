// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock ERC20 that burns 10% of every transfer so received amount < `amount`.
contract MockFeeOnTransferERC20 is ERC20 {
    uint8 private immutable _tokenDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _tokenDecimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            // Integer division truncates; tiny transfers may have fee == 0. Fine for this test mock.
            uint256 fee = value / 10;
            super._update(from, to, value - fee);
            if (fee > 0) {
                super._update(from, address(0), fee);
            }
            return;
        }
        super._update(from, to, value);
    }
}
