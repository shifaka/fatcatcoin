// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts@5.1.0/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts@5.1.0/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20Permit.sol";

contract FatCatCoin is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    mapping(address => uint256) private _stakes;
    mapping(address => uint256) private _stakeTimestamps;

    uint256 public constant APR = 30; // 30% Annual Percentage Rate
    uint256 public constant SECONDS_IN_YEAR = 365 days;
    uint256 public immutable STAKING_POOL_ALLOCATION; // Initialized in constructor

    uint256 private _stakingPool;

    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount, uint256 rewards);

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {
        uint256 totalSupply = 1000000000 * 10 ** decimals();
        _mint(msg.sender, totalSupply);

        // Initialize staking pool with 30% of the total supply
        STAKING_POOL_ALLOCATION = (totalSupply * 30) / 100;
        _stakingPool = STAKING_POOL_ALLOCATION;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    /**
     * @dev Stake tokens.
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake zero tokens");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to stake");

        // Add rewards for previous staking period, if applicable
        if (_stakes[msg.sender] > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            distributeRewards(msg.sender, rewards);
        }

        _stakes[msg.sender] += amount;
        _stakeTimestamps[msg.sender] = block.timestamp;

        _transfer(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Unstake tokens and claim rewards.
     */
    function unstake(uint256 amount) external {
        require(amount > 0, "Cannot unstake zero tokens");
        require(_stakes[msg.sender] >= amount, "Insufficient staked balance");

        uint256 rewards = calculateRewards(msg.sender);
        _stakes[msg.sender] -= amount;

        // Reset timestamp if no tokens remain staked
        if (_stakes[msg.sender] == 0) {
            _stakeTimestamps[msg.sender] = 0;
        } else {
            _stakeTimestamps[msg.sender] = block.timestamp;
        }

        distributeRewards(msg.sender, rewards);
        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount, rewards);
    }

    /**
     * @dev Distribute rewards from the staking pool.
     */
    function distributeRewards(address recipient, uint256 rewards) internal {
        require(_stakingPool >= rewards, "Not enough tokens in staking pool");
        _stakingPool -= rewards;
        _transfer(address(this), recipient, rewards);
    }

    /**
     * @dev Calculate staking rewards for an account based on APR and staking duration.
     */
    function calculateRewards(address account) public view returns (uint256) {
        if (_stakes[account] == 0 || _stakeTimestamps[account] == 0) {
            return 0;
        }

        uint256 stakingDuration = block.timestamp - _stakeTimestamps[account];
        uint256 yearlyRewards = (_stakes[account] * APR) / 100;
        return (yearlyRewards * stakingDuration) / SECONDS_IN_YEAR;
    }

    /**
     * @dev View staked balance of an account.
     */
    function stakedBalance(address account) external view returns (uint256) {
        return _stakes[account];
    }

    /**
     * @dev View total rewards earned so far by an account.
     */
    function viewRewards(address account) external view returns (uint256) {
        return calculateRewards(account);
    }

    /**
     * @dev View remaining tokens in the staking pool.
     */
    function stakingPoolBalance() external view returns (uint256) {
        return _stakingPool;
    }
}
