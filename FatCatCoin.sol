// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts@5.1.0/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts@5.1.0/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20Permit.sol";

contract FatCatCoin is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    uint256 public constant STAKING_POOL = 300_000_000 * 10 ** 18; // 30% of total supply
    uint256 public constant APR = 30; // 30% APR
    uint256 public immutable stakingStartTime;

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public stakingTimestamps;

    uint256 public stakingPoolBalance;

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        stakingPoolBalance = STAKING_POOL;
        stakingStartTime = block.timestamp;
    }

    /// @notice Stake tokens into the staking pool
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(stakingPoolBalance >= amount, "Not enough tokens in the staking pool");

        // Transfer tokens to the contract
        _transfer(msg.sender, address(this), amount);

        // Update staking data
        stakedBalances[msg.sender] += amount;
        stakingTimestamps[msg.sender] = block.timestamp;

        stakingPoolBalance -= amount;
    }

    /// @notice Unstake tokens and claim rewards
    // Declare the event
    event Unstake(address indexed user, uint256 stakedAmount, uint256 reward);

    function unstake() external {
        uint256 stakedAmount = stakedBalances[msg.sender];
        require(stakedAmount > 0, "No tokens staked");

        uint256 stakingDuration = block.timestamp - stakingTimestamps[msg.sender];
        uint256 reward = calculateRewards(stakedAmount, stakingDuration);

        // Ensure the staking pool has enough balance for the reward
        require(stakingPoolBalance >= reward, "Insufficient staking pool balance");

        // Update staking pool balance
        stakingPoolBalance -= reward;

        // Reset user staking data
        stakedBalances[msg.sender] = 0;
        stakingTimestamps[msg.sender] = 0;

        // Transfer staked amount + reward from the contract to the user
        _transfer(address(this), msg.sender, stakedAmount + reward);

        // Emit the Unstake event
        emit Unstake(msg.sender, stakedAmount, reward);
    }


    /// @notice Calculate rewards based on staked amount and time
    function calculateRewards(uint256 amount, uint256 duration) public pure returns (uint256) {
        return (amount * APR * duration) / (365 days * 100);
    }

    /// @notice View the rewards for a staker
    function checkRewards(address staker) external view returns (uint256) {
        uint256 stakedAmount = stakedBalances[staker];
        if (stakedAmount == 0) return 0;

        uint256 stakingDuration = block.timestamp - stakingTimestamps[staker];
        return calculateRewards(stakedAmount, stakingDuration);
    }

    /// @notice View the balance of the staking pool
    function getStakingPoolBalance() external view returns (uint256) {
        return stakingPoolBalance;
    }
}
