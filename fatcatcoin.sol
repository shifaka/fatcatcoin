// SPDX-License-Identifier: MIT
// fatcatcoin.io
// FAT token smart contract

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
    uint256 public stakingAPR = 40;
    uint256 public rewardsPaid;
    uint256 public cooldownPeriod = 10 days;

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
    event StakingPoolFilluped(address indexed admin, uint256 amount);

    address private _thisAddress = address(this);

    constructor(address defaultAdmin)
        ERC20("FatCatCoin", "FAT")
        ERC20Permit("FatCatCoin")
    {
        uint256 totalSupply = 1e9 * 1e18;
        address localThisAddress = _thisAddress;
        _mint(msg.sender, totalSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        // Team Tokens Freeze
        uint256 teamTokens = totalSupply / 10;
        frozenTokens = teamTokens;
        freezeReleaseTime = block.timestamp + 180 days;
        _transfer(msg.sender, localThisAddress, teamTokens);

        uint256 stakingTokens = totalSupply * 30 / 100;
        stakingPool = stakingTokens;
        _transfer(msg.sender, localThisAddress, stakingTokens);

        emit TokensFrozen(teamTokens);
    }

    modifier onlyInvestor() {
        require(balanceOf(msg.sender) > 0 || stakingData[msg.sender].balance > 0, "Caller is not an investor (no tokens or staked tokens)");
        _;
    }

    function isFreezePeriodOver() public view returns (bool) {
        return block.timestamp > freezeReleaseTime;
    }

    function unfreezeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > freezeReleaseTime, "Tokens are still frozen");

        uint256 frozenAmount = frozenTokens;
        frozenTokens = 0;
        _transfer(_thisAddress, msg.sender, frozenAmount);

        emit TokensUnfrozen(frozenAmount);
    }

    function stake(uint256 amount) public onlyInvestor {
        StakingInfo storage userStakingData = stakingData[msg.sender];
        address localThisAddress = _thisAddress;
        require(amount != 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) > amount - 1, "Insufficient balance to stake");
        _transfer(msg.sender, localThisAddress, amount);
        userStakingData.balance = userStakingData.balance + amount;
        totalStaked = totalStaked + amount;
        userStakingData.lastStakingTime = block.timestamp;
        emit TokensStaked(msg.sender, amount);
    }

    function unstake(uint256 amount) public onlyInvestor {
        StakingInfo storage userStakingData = stakingData[msg.sender];
        uint256 userStakedBalance = userStakingData.balance;
        uint256 userStakingTimestamp = userStakingData.lastStakingTime;

        require(userStakedBalance > amount - 1, "Insufficient staked balance");
        require(block.timestamp > userStakingTimestamp + cooldownPeriod, "Cooldown period not passed");

        uint256 rewards = calculateRewards(msg.sender);
        userStakingData.balance = userStakedBalance - amount;
        totalStaked = totalStaked - amount;
        stakingPool = stakingPool - rewards;
        rewardsPaid = rewardsPaid + rewards;
        _transfer(_thisAddress, msg.sender, amount + rewards);
        userStakingData.lastStakingTime = 0;

        emit TokensUnstaked(msg.sender, amount, rewards);
    }

    function calculateRewards(address user) public view onlyInvestor returns (uint256 rewards) {
        StakingInfo storage userStakingData = stakingData[user];
        uint256 stakedAmount = userStakingData.balance;
        uint256 lastStakingTime = userStakingData.lastStakingTime;
        uint256 apr = stakingAPR;
        uint256 stakingDuration = block.timestamp - lastStakingTime;
        uint256 annualRewards = (stakedAmount * apr) / 100;

        rewards = (annualRewards * stakingDuration) / 365 days;
    }

    function addToStakingPool(uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount != 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) > amount - 1, "Insufficient admin balance");
        
        _transfer(msg.sender, _thisAddress, amount);        
        stakingPool = stakingPool + amount;

        emit StakingPoolFilluped(msg.sender, amount);
    }

    function strokeFatCatCat() public pure returns (string memory) {
        return "       /\\_/\\  \n"
               "      ( o.o ) \n"
               "       > ^ <  \n"
               "   The Fat Cat is watching you: fatcatcoin.io";
    }
}
