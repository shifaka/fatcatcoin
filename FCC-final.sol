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
    uint256 public baseAPR = 30; // Base APR (30%)
    uint256 public stakingAPR = 30; // Current APR (can change with multiplier)
    uint256 public rewardsPaid; // Total amount of rewards paid out
    uint256 public cooldownPeriod = 1 minutes; // Cooldown period for unstaking
    uint256 public lastAPRUpdate; // Last time APR was updated
    uint256 public multiplierCount; // Number of times the APR multiplier has been applied

    uint256 public constant APR_MULTIPLIER = 11; // Maximum number of multipliers
    //uint256 public constant MULTIPLIER_PERIOD = 30 days; // Period for APR multiplication
    uint256 public constant MULTIPLIER_PERIOD = 30 seconds; // Period for APR multiplication

    mapping(address => uint256) public stakedBalances; // User's staked tokens
    mapping(address => uint256) public stakingTimestamps; // Last staking time for each user

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {
        uint256 totalSupply = 1000000000 * 10 ** decimals();
        _mint(msg.sender, totalSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        // Freeze 10% of the total supply for 180 days
        uint256 teamTokens = totalSupply / 10;
        frozenTokens = teamTokens;
        freezeReleaseTime = block.timestamp + 1 minutes; 
        
        _transfer(msg.sender, address(this), teamTokens);

        // Reserve 30% of the total supply for staking
        uint256 stakingTokens = totalSupply * 30 / 100;
        stakingPool = stakingTokens;
        _transfer(msg.sender, address(this), stakingTokens);

        // Initialize APR timing
        lastAPRUpdate = block.timestamp;
        multiplierCount = 0;
    }

    function updateAPR() public {
        // Check if it's time to apply the multiplier
        if (block.timestamp >= lastAPRUpdate + MULTIPLIER_PERIOD) {
            uint256 periodsElapsed = (block.timestamp - lastAPRUpdate) / MULTIPLIER_PERIOD;

            // Update APR based on elapsed periods
            for (uint256 i = 0; i < periodsElapsed; i++) {
                if (multiplierCount < APR_MULTIPLIER) {
                    stakingAPR = (stakingAPR * 11) / 10; // Increase APR by 1.1x
                    multiplierCount++;
                } else {
                    stakingAPR = baseAPR; // Reset to base APR
                    multiplierCount = 0; // Reset multiplier count
                }
            }

            // Update the last APR update time
            lastAPRUpdate += periodsElapsed * MULTIPLIER_PERIOD;
        }
    }

    function calculateRewards(address user) public view returns (uint256) {
        uint256 stakedAmount = stakedBalances[user];
        uint256 stakingDuration = block.timestamp - stakingTimestamps[user];

        // Simulate APR update without state changes
        uint256 simulatedAPR = stakingAPR;
        uint256 simulatedMultiplierCount = multiplierCount;
        uint256 simulatedLastAPRUpdate = lastAPRUpdate;

        if (block.timestamp >= simulatedLastAPRUpdate + MULTIPLIER_PERIOD) {
            uint256 periodsElapsed = (block.timestamp - simulatedLastAPRUpdate) / MULTIPLIER_PERIOD;

            for (uint256 i = 0; i < periodsElapsed; i++) {
                if (simulatedMultiplierCount < APR_MULTIPLIER) {
                    simulatedAPR = (simulatedAPR * 11) / 10;
                    simulatedMultiplierCount++;
                } else {
                    simulatedAPR = baseAPR;
                    simulatedMultiplierCount = 0;
                }
            }
        }

        // Calculate annual rewards with the simulated APR
        uint256 annualRewards = (stakedAmount * simulatedAPR) / 100;

        // Calculate rewards based on the staking duration
        uint256 rewards = (annualRewards * stakingDuration) / 365 days;

        return rewards;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");

        // Update APR before staking
        updateAPR();

        _transfer(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
        stakingTimestamps[msg.sender] = block.timestamp;
    }

    function unstake(uint256 amount) public {
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        require(block.timestamp >= stakingTimestamps[msg.sender] + cooldownPeriod, "Cooldown period not passed");

        // Update APR before unstaking
        updateAPR();

        uint256 rewards = calculateRewards(msg.sender);
        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;

        stakingPool -= rewards;
        rewardsPaid += rewards;

        _transfer(address(this), msg.sender, amount + rewards);
        stakingTimestamps[msg.sender] = 0;
    }
}
