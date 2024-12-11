// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FatCatCoin is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    using SafeERC20 for ERC20; // Use SafeERC20 for safe transfers

    uint256 public frozenTokens; // Amount of tokens frozen
    uint256 public freezeReleaseTime; // Time when the tokens can be unfrozen
    uint256 public stakingPool; // Amount of tokens in the staking pool
    uint256 public totalStaked; // Total amount of staked tokens
    uint256 public stakingAPR = 30; // Annual Percentage Rate (30% APR)
    uint256 public rewardsPaid; // Total amount of rewards paid out
    uint256 public cooldownPeriod = 1 minutes; // Cooldown period for unstaking

    // Staking-related mappings    
    struct StakingInfo {
        uint256 balance; // Staked tokens
        uint256 lastStakingTime; // Timestamp of last staking
    }
    mapping(address user => StakingInfo info) public stakingData;

    // Optimized Events with Indexed Parameters    
    event TokensFrozen(uint256 amount);
    event TokensUnfrozen(uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount, uint256 rewards);
    event TransferBlocked(address indexed from, address indexed to, uint256 amount);

    address private _thisAddress = address(this);    

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {        
        uint256 totalSupply = 1e9 * 1e18;
        address localThisAddress = _thisAddress;

        _mint(msg.sender, totalSupply); // Mint all tokens
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        
        // Freeze 10% of the total supply for 180 days
        uint256 teamTokens = totalSupply / 10;
        frozenTokens = teamTokens;
        freezeReleaseTime = block.timestamp + 1 minutes; // For testing, 1 minute (change for production)

        // Transfer frozen tokens to the contract address for locking
        _transfer(msg.sender, localThisAddress, teamTokens);

        // Reserve 30% of the total supply for the staking pool
        uint256 stakingTokens = totalSupply * 30 / 100;
        stakingPool = stakingTokens;
        _transfer(msg.sender, localThisAddress, stakingTokens); // Transfer staking tokens to the contract

        emit TokensFrozen(teamTokens);
    }

    // Modifier to ensure the caller has tokens in their balance or has staked tokens
    modifier onlyInvestor() {
        require(balanceOf(msg.sender) > 0 || stakingData[msg.sender].balance > 0, "Caller is not an investor (no tokens or staked tokens)");
        _;
    }

    // Override the transfer function to block transfers of frozen tokens
    function transfer(address recipient, uint256 amount) public override onlyInvestor returns (bool) {
        // If the tokens are frozen and the freeze period has not passed, prevent transfer
        address localThisAddress = _thisAddress;
        if (balanceOf(localThisAddress) >= frozenTokens ) {
            require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");
            emit TransferBlocked(msg.sender, recipient, amount); // Emit event if transfer is blocked
        }

        super.transfer(recipient, amount);
        return true;
    }

    // Override the transferFrom function to block transfers of frozen tokens
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override onlyInvestor returns (bool) {
        // Cache state variables in memory
        uint256 cachedBalance = balanceOf(_thisAddress);
        uint256 cachedFrozenTokens = frozenTokens;
        uint256 localFreezeReleaseTime = freezeReleaseTime;
        address localThisAddress = _thisAddress;        

        // If the tokens are frozen and the freeze period has not passed, prevent transfer
        if (cachedBalance >= cachedFrozenTokens) {
            require(block.timestamp > localFreezeReleaseTime, "Tokens are still frozen");
            emit TransferBlocked(sender, recipient, amount); // Emit event if transfer is blocked
        }

        ERC20(localThisAddress).safeTransferFrom(sender, recipient, amount); // Safe transfer
        return true;
    }

    // Function to check if the freeze period is over
    function isFreezePeriodOver() public view returns (bool) {
        return block.timestamp > freezeReleaseTime;
    }

    // Function to unfreeze tokens and transfer them to the contract deployer's address
    function unfreezeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 localFreezeReleaseTime = freezeReleaseTime;
        require(block.timestamp > localFreezeReleaseTime, "Tokens are still frozen");
        uint256 frozenAmount = frozenTokens;
        address localThisAddress = _thisAddress;
        frozenTokens = 0; // Reset the frozenTokens variable
        _transfer(localThisAddress, msg.sender, frozenAmount);

        emit TokensUnfrozen(frozenAmount); // Emit event on unfreezing tokens
    }

    // Function to stake tokens
    function stake(uint256 amount) public onlyInvestor {
        require(amount != 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) > amount - 1, "Insufficient balance to stake");
        address localThisAddress = _thisAddress;
        uint256 localTotalStaked = totalStaked;

        // Transfer the tokens from the user to the contract for staking
        _transfer(msg.sender, localThisAddress, amount);

        // Update the user's staked balance and the total staked amount
        //stakedBalances[msg.sender] = stakedBalances[msg.sender] + amount;
        stakingData[msg.sender].balance = stakingData[msg.sender].balance + amount;
        totalStaked = localTotalStaked + amount;

        // Record the staking timestamp
        // stakingTimestamps[msg.sender] = block.timestamp;
        stakingData[msg.sender].lastStakingTime = block.timestamp;

        emit TokensStaked(msg.sender, amount); // Emit event when tokens are staked
    }

    // Function to unstake tokens and claim rewards, with cooldown period enforcement
    function unstake(uint256 amount) public onlyInvestor {
        uint256 userStakedBalance = stakingData[msg.sender].balance;
        uint256 userStakingTimestamp = stakingData[msg.sender].lastStakingTime;
        
        require(userStakedBalance > amount - 1, "Insufficient staked balance");
        require(block.timestamp > userStakingTimestamp + cooldownPeriod, "Cooldown period not passed");
        // Calculate staking rewards
        uint256 rewards = calculateRewards(msg.sender);
        address localThisAddress = _thisAddress;  
        // Update the user's staked balance and total staked amount        
        stakingData[msg.sender].balance = userStakedBalance - amount;
        totalStaked = totalStaked - amount;
        // Deduct the rewards from the staking pool
        stakingPool = stakingPool - rewards;
        rewardsPaid = rewardsPaid + rewards;        
        // Transfer staked tokens and rewards back to the user
        _transfer(localThisAddress, msg.sender, amount + rewards);        
        // Reset staking timestamp as the user has unstaked
        stakingData[msg.sender].lastStakingTime = 0;

        emit TokensUnstaked(msg.sender, amount, rewards); // Emit event when tokens are unstaked and rewards are paid
    }

    // Function to calculate the staking rewards based on 30% APR
    function calculateRewards(address user) public onlyInvestor view returns (uint256 rewards) {
        uint256 stakedAmount = stakingData[msg.sender].balance;        
        uint256 stakingDuration = block.timestamp - stakingData[user].lastStakingTime;
        // Calculate the annual rewards based on 30% APR
        uint256 annualRewards = (stakedAmount * stakingAPR) / 100;

        // Calculate the rewards based on the duration the tokens have been staked
        rewards = (annualRewards * stakingDuration) / 365 days;
    }
}
