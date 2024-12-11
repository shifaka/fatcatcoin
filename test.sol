// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.22;
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FatCatCoin is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    using SafeERC20 for ERC20;

    uint256 public frozenTokens;
    uint256 public freezeReleaseTime;
    uint256 public stakingPool;
    uint256 public totalStaked;
    uint256 public stakingAPR = 30;
    uint256 public rewardsPaid;
    uint256 public cooldownPeriod = 1 minutes;

    struct StakingInfo {
        uint256 balance;
        uint256 lastStakingTime;
    }

    mapping(address user => StakingInfo info) public stakingData;

    event TokensFrozen(uint256 amount);
    event TokensUnfrozen(uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount, uint256 rewards);
    event TransferBlocked(address indexed from, address indexed to, uint256 amount);

    address private _thisAddress = address(this);
    address public owner;

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {        
        uint256 totalSupply = 1e9 * 1e18;
        _mint(msg.sender, totalSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        uint256 teamTokens = totalSupply / 10;
        frozenTokens = teamTokens;
        freezeReleaseTime = block.timestamp + 1 minutes;

        _transfer(msg.sender, _thisAddress, teamTokens);

        uint256 stakingTokens = totalSupply * 30 / 100;
        stakingPool = stakingTokens;
        _transfer(msg.sender, _thisAddress, stakingTokens);

        owner = msg.sender;

        emit TokensFrozen(teamTokens);
    }

    modifier onlyInvestor() {
        require(balanceOf(msg.sender) > 0 || stakingData[msg.sender].balance > 0, "Caller is not an investor");
        _;
    }

    function transfer(address recipient, uint256 amount) public override onlyInvestor returns (bool) {
        uint256 contractBalance = balanceOf(_thisAddress);
        if (contractBalance >= frozenTokens) {
            require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");
            emit TransferBlocked(msg.sender, recipient, amount);
        }
        super.transfer(recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override onlyInvestor returns (bool) {
        uint256 contractBalance = balanceOf(_thisAddress);
        if (contractBalance >= frozenTokens) {
            require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");
            emit TransferBlocked(sender, recipient, amount);
        }
        ERC20(_thisAddress).safeTransferFrom(sender, recipient, amount);
        return true;
    }

    function unfreezeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");

        uint256 frozenAmount = frozenTokens;
        frozenTokens = 0;
        _transfer(_thisAddress, msg.sender, frozenAmount);

        emit TokensUnfrozen(frozenAmount);
    }

    function stake(uint256 amount) public onlyInvestor {
        require(amount != 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) > amount - 1, "Insufficient balance to stake");

        _transfer(msg.sender, _thisAddress, amount);

        StakingInfo storage info = stakingData[msg.sender];
        info.balance += amount;
        totalStaked += amount;

        info.lastStakingTime = block.timestamp;

        emit TokensStaked(msg.sender, amount);
    }

    function unstake(uint256 amount) public onlyInvestor {
        StakingInfo storage info = stakingData[msg.sender];
        uint256 userStakedBalance = info.balance;
        uint256 userStakingTimestamp = info.lastStakingTime;

        require(userStakedBalance > amount - 1, "Insufficient staked balance");
        require(block.timestamp > userStakingTimestamp + cooldownPeriod, "Cooldown period not passed");

        uint256 rewards = calculateRewards(msg.sender);

        info.balance -= amount;
        totalStaked -= amount;

        stakingPool -= rewards;
        rewardsPaid += rewards;

        _transfer(_thisAddress, msg.sender, amount + rewards);

        info.lastStakingTime = 0;

        emit TokensUnstaked(msg.sender, amount, rewards);
    }

    function calculateRewards(address user) public view onlyInvestor returns (uint256 rewards) {
        StakingInfo storage info = stakingData[user];
        uint256 stakedAmount = info.balance;
        uint256 stakingDuration = block.timestamp - info.lastStakingTime;

        uint256 annualRewards = (stakedAmount * stakingAPR) / 100;
        rewards = (annualRewards * stakingDuration) / 365 days;
    }
}
