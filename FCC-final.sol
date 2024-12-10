// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FatCatCoin is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    uint256 public frozenTokens; // Amount of tokens frozen
    uint256 public freezeReleaseTime; // Time when the tokens can be unfrozen

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {
        uint256 totalSupply = 1000000000 * 10 ** decimals();
        _mint(msg.sender, totalSupply); // Mint all tokens
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        // Freeze 10% of the total supply for 180 days
        uint256 teamTokens = totalSupply / 10;
        frozenTokens = teamTokens;
        freezeReleaseTime = block.timestamp + 180 days;

        // Transfer frozen tokens to the contract address for locking
        _transfer(msg.sender, address(this), teamTokens);
    }

    // Override the transfer function to block transfers of frozen tokens
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        // If the tokens are frozen and the freeze period has not passed, prevent transfer
        if (balanceOf(address(this)) >= frozenTokens) {
            require(block.timestamp >= freezeReleaseTime, "Tokens are frozen and cannot be transferred yet");
        }

        return super.transfer(recipient, amount);
    }

    // Override the transferFrom function to block transfers of frozen tokens
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        // If the tokens are frozen and the freeze period has not passed, prevent transfer
        if (balanceOf(address(this)) >= frozenTokens) {
            require(block.timestamp >= freezeReleaseTime, "Tokens are frozen and cannot be transferred yet");
        }

        return super.transferFrom(sender, recipient, amount);
    }

    // Function to check if the freeze period is over
    function isFreezePeriodOver() public view returns (bool) {
        return block.timestamp >= freezeReleaseTime;
    }
}
