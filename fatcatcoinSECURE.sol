// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FatCatCoin is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    uint256 public frozenTokens; // Amount of tokens frozen
    uint256 public freezeReleaseTime; // Time when the tokens can be unfrozen
    uint256 public stakingPool; // Amount of tokens in the staking pool
    uint256 public totalStaked; // Total amount of staked tokens
    uint256 public stakingAPR = 30; // Annual Percentage Rate (30% APR)
    uint256 public rewardsPaid; // Total amount of rewards paid out
    //uint256 public cooldownPeriod = 10 days; // Cooldown period for unstaking
    uint256 public cooldownPeriod = 1 minutes; // Cooldown period for unstaking

    // Staking-related mappings
    mapping(address => uint256) public stakedBalances; // User's staked tokens
    mapping(address => uint256) public stakingTimestamps; // Last staking time for each user

    // Define Events
    event TokensFrozen(uint256 amount, uint256 releaseTime);
    event TokensUnfrozen(uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount, uint256 rewards);
    event TransferBlocked(address indexed from, address indexed to, uint256 amount);

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {
        uint256 totalSupply = 1000000000 * 10 ** decimals();
        _mint(msg.sender, totalSupply); // Mint all tokens
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        address thisAddress = address(this); // Cache address(this)

        // Freeze 10% of the total supply for 180 days
        uint256 teamTokens = totalSupply / 10;
        frozenTokens = teamTokens;
        freezeReleaseTime = block.timestamp + 1 minutes; // For testing, 1 minute (change for production)
        
        // Transfer frozen tokens to the contract address for locking
        _transfer(msg.sender, thisAddress, teamTokens);

        // Reserve 30% of the total supply for the staking pool
        uint256 stakingTokens = totalSupply * 30 / 100;
        stakingPool = stakingTokens;
        _transfer(msg.sender, thisAddress, stakingTokens); // Transfer staking tokens to the contract

        emit TokensFrozen(teamTokens, freezeReleaseTime);
    }

    // Override the transfer function to block transfers of frozen tokens
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        // If the tokens are frozen and the freeze period has not passed, prevent transfer
        if (balanceOf(address(this)) >= frozenTokens) {
            require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");
            emit TransferBlocked(msg.sender, recipient, amount); // Emit event if transfer is blocked
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
            require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");
            emit TransferBlocked(sender, recipient, amount); // Emit event if transfer is blocked
        }

        return super.transferFrom(sender, recipient, amount);
    }

    // Function to check if the freeze period is over
    function isFreezePeriodOver() public view returns (bool) {
        return block.timestamp >= freezeReleaseTime;
    }

    // Function to unfreeze tokens and transfer them to the contract deployer's address
    function unfreezeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");

        uint256 frozenAmount = frozenTokens;
        frozenTokens = 0; // Reset the frozenTokens variable
        _transfer(address(this), msg.sender, frozenAmount);

        emit TokensUnfrozen(frozenAmount); // Emit event on unfreezing tokens
    }

    // Function to stake tokens
    function stake(uint256 amount) public {
        require(amount != 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");

        // Transfer the tokens from the user to the contract for staking
        _transfer(msg.sender, address(this), amount);

        // Update the user's staked balance and the total staked amount
        stakedBalances[msg.sender] = stakedBalances[msg.sender] + amount;
        totalStaked = totalStaked + amount;

        // Record the staking timestamp
        stakingTimestamps[msg.sender] = block.timestamp;

        emit TokensStaked(msg.sender, amount); // Emit event when tokens are staked
    }

    // Function to unstake tokens and claim rewards, with cooldown period enforcement
    function unstake(uint256 amount) public {
        uint256 userStakedBalance = stakedBalances[msg.sender];
        uint256 userStakingTimestamp = stakingTimestamps[msg.sender];
        
        require(userStakedBalance >= amount, "Insufficient staked balance");
        
        // Ensure the cooldown period has passed since staking
        require(block.timestamp > userStakingTimestamp + cooldownPeriod, "Cooldown period not passed");
        
        // Calculate staking rewards
        uint256 rewards = calculateRewards(msg.sender);
        
        // Update the user's staked balance and total staked amount
        stakedBalances[msg.sender] = userStakedBalance - amount;
        totalStaked = totalStaked - amount;

        // Deduct the rewards from the staking pool
        stakingPool = stakingPool - rewards;
        rewardsPaid = rewardsPaid + rewards;

        // Transfer staked tokens and rewards back to the user
        _transfer(address(this), msg.sender, amount + rewards);
        
        // Reset staking timestamp as the user has unstaked
        stakingTimestamps[msg.sender] = 0;

        emit TokensUnstaked(msg.sender, amount, rewards); // Emit event when tokens are unstaked and rewards are paid
    }

    // Function to calculate the staking rewards based on 30% APR
    function calculateRewards(address user) public view returns (uint256) {
        uint256 stakedAmount = stakedBalances[user];
        uint256 stakingDuration = block.timestamp - stakingTimestamps[user];
        
        // Calculate the annual rewards based on 30% APR
        uint256 annualRewards = (stakedAmount * stakingAPR) / 100;

        // Calculate the rewards based on the duration the tokens have been staked
        uint256 rewards = (annualRewards * stakingDuration) / 365 days;

        return rewards;
    }
}