// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FatCatCoin is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    uint256 public frozenTokens;
    uint256 public freezeReleaseTime;
    uint256 public stakingPool;
    uint256 public totalStaked;
    uint256 public baseAPR = 30; // Base APR (30%)
    uint256 public currentAPR = 30; // Current APR (starts at base)
    uint256 public rewardsPaid;
    uint256 public cooldownPeriod = 1 minutes; // Cooldown period for unstaking

    uint256 public multiplierResetTime; // Timestamp for the next reset
    //uint256 public multiplierDuration = 30 days; // Monthly duration for APR multiplier
    uint256 public multiplierDuration = 30 seconds; // Monthly duration for APR multiplier
    uint256 public multiplierCount = 0; // Tracks the number of multiplier applications

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public stakingTimestamps;

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {
        uint256 totalSupply = 1000000000 * 10 ** decimals();
        _mint(msg.sender, totalSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        uint256 teamTokens = totalSupply / 10;
        frozenTokens = teamTokens;
        freezeReleaseTime = block.timestamp + 1 minutes;

        _transfer(msg.sender, address(this), teamTokens);

        uint256 stakingTokens = totalSupply * 30 / 100;
        stakingPool = stakingTokens;
        _transfer(msg.sender, address(this), stakingTokens);

        multiplierResetTime = block.timestamp + multiplierDuration; // Initialize reset time
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if (balanceOf(address(this)) >= frozenTokens) {
            require(block.timestamp >= freezeReleaseTime, "Tokens are frozen and cannot be transferred yet");
        }
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        if (balanceOf(address(this)) >= frozenTokens) {
            require(block.timestamp >= freezeReleaseTime, "Tokens are frozen and cannot be transferred yet");
        }
        return super.transferFrom(sender, recipient, amount);
    }

    function isFreezePeriodOver() public view returns (bool) {
        return block.timestamp >= freezeReleaseTime;
    }

    function unfreezeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only the admin can unfreeze tokens");
        require(block.timestamp >= freezeReleaseTime, "The freeze period has not yet ended");

        uint256 frozenAmount = frozenTokens;
        frozenTokens = 0;
        _transfer(address(this), msg.sender, frozenAmount);
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");

        _transfer(msg.sender, address(this), amount);

        stakedBalances[msg.sender] += amount;
        totalStaked += amount;

        stakingTimestamps[msg.sender] = block.timestamp;
    }

    function unstake(uint256 amount) public {
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        require(block.timestamp >= stakingTimestamps[msg.sender] + cooldownPeriod, "Cooldown period not passed");

        updateAPR(); // Ensure APR is updated

        uint256 rewards = calculateRewards(msg.sender);

        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;

        stakingPool -= rewards;
        rewardsPaid += rewards;

        _transfer(address(this), msg.sender, amount + rewards);

        stakingTimestamps[msg.sender] = 0;
    }

    function calculateRewards(address user) public view returns (uint256) {
        uint256 stakedAmount = stakedBalances[user];
        uint256 stakingDuration = block.timestamp - stakingTimestamps[user];

        uint256 annualRewards = (stakedAmount * currentAPR) / 100;
        uint256 rewards = (annualRewards * stakingDuration) / 365 days;

        return rewards;
    }

    function updateAPR() public {
        if (block.timestamp >= multiplierResetTime) {
            if (multiplierCount < 11) {
                currentAPR = (currentAPR * 110) / 100; // Increase APR by 10%
                multiplierCount++;
            } else {
                currentAPR = baseAPR; // Reset to base APR after 11 months
                multiplierCount = 0;
            }
            multiplierResetTime = block.timestamp + multiplierDuration; // Set next reset time
        }
    }
}