// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {

    IERC20 public token;  // The token being staked
    uint256 public stakingPoolBalance;  // The staking pool balance
    address public stakingWallet;  // The address receiving staking rewards

    mapping(address => uint256) public stakedBalances;  // User staked balance
    mapping(address => uint256) public stakingTimestamps;  // Timestamp of user's stake

    uint256 public constant APR = 30;  // Annual Percentage Rate for rewards (30%)

    event Unstake(address indexed user, uint256 stakedAmount, uint256 reward);

    constructor(address _token, address _stakingWallet) {
        token = IERC20(_token);
        stakingWallet = _stakingWallet;
    }

    // Unstake function: Unstakes tokens and transfers rewards
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
        token.transfer(msg.sender, stakedAmount);
        token.transfer(stakingWallet, reward);

        // Emit Unstake event
        emit Unstake(msg.sender, stakedAmount, reward);
    }

    // Calculate staking rewards based on the staking duration
    function calculateRewards(uint256 stakedAmount, uint256 duration) internal pure returns (uint256) {
        uint256 yearlyReward = (stakedAmount * APR) / 100;
        return (yearlyReward * duration) / (365 days);  // Linear reward calculation
    }

    // Function to allow users to stake tokens (just for context)
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        // Transfer tokens to the contract
        token.transferFrom(msg.sender, address(this), amount);

        // Update staking balance and timestamp
        stakedBalances[msg.sender] += amount;
        stakingTimestamps[msg.sender] = block.timestamp;

        // Increase the staking pool balance
        stakingPoolBalance += calculateRewards(amount, 0);  // Reward for the future staking duration
    }
}

