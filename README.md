# 🐱 Fat Cat Coin (FAT) Smart Contract

Welcome to the **Fat Cat Coin** smart contract repository! 🎉 FAT is a super cool meme coin with utility and staking features. Our mission is to combine humor, community, and financial growth through innovative tokenomics and engaging rewards. 🚀

---

## 🌟 Key Features

### 💰 Total Supply
- **1,000,000,000 FAT tokens** minted at launch.

### 🧾 Tokenomics
- **10% Team Tokens:** Frozen for 180 days to ensure trust and long-term commitment. 🔒
- **30% Staking Pool:** Dedicated to rewarding the community for staking their FAT tokens. 🏦

### 📈 Staking
- Earn an **amazing 40% APR** by staking your FAT tokens. 🎉
- Staking comes with a **10-day cooldown period** before unstaking is allowed. ⏳
- Rewards are calculated based on staking duration and added to your unstaked amount. 💸

### 🛡️ Security Features
- Team tokens are locked until the freeze period ends. ⛓️
- Transfers are restricted for investors without holdings or staked tokens. 🚫

---

## 💻 Smart Contract Details

### 🔧 Functions

#### **Staking**
- `stake(uint256 amount)`: Stake your FAT tokens to earn rewards. 💎
- `unstake(uint256 amount)`: Unstake your FAT tokens along with accrued rewards (after the cooldown period). 🎁
- `calculateRewards(address user)`: View your pending staking rewards. 📊

#### **Freeze Mechanism**
- `isFreezePeriodOver()`: Check if the team tokens are still frozen. ❄️
- `unfreezeTokens()`: Admin-only function to release frozen team tokens once the freeze period is over. 🔓

#### **Special Easter Egg** 🥚
- `strokeFatCatCat()`: Displays a cute ASCII art of the Fat Cat. 😺

```
       /\_/\  
      ( o.o ) 
       > ^ <  
   The Fat Cat is watching you: fatcatcoin.io
```

---

## ⚙️ How It Works

1. **Freeze Period**:
   - 10% of the total supply is frozen at contract creation. ❄️
   - These tokens will be unfrozen only after 180 days. 🗓️
2. **Staking Rewards**:
   - Users stake FAT tokens and earn rewards proportional to their staking duration. 🤑
   - Rewards are paid from the 30% staking pool. 💰
3. **Cooldown Period**:
   - After staking, a cooldown of 10 days is required before unstaking. ⏳

---

## 🌍 Deployment
- **Network:** Binance Smart Chain (BSC) 🌐
- **Solidity Version:** Compatible with Solidity 0.8.26 🛠️
- **Dependencies:**
  - OpenZeppelin Contracts (Access Control, ERC20, Burnable, Permit, and SafeERC20).

---

## 📡 Events
- `TokensFrozen(uint256 amount)`: Emitted when tokens are frozen. ❄️
- `TokensUnfrozen(uint256 amount)`: Emitted when tokens are unfrozen. 🔓
- `TokensStaked(address indexed user, uint256 amount)`: Emitted when a user stakes tokens. 💎
- `TokensUnstaked(address indexed user, uint256 amount, uint256 rewards)`: Emitted when a user unstakes tokens and receives rewards. 🎁
- `TransferBlocked(address indexed from, address indexed to, uint256 amount)`: Emitted when a transfer attempt fails during the freeze period. 🚫

---

## 💬 Fat Cat Coin Community
- 🌐 Website: [fatcatcoin.io](https://fatcatcoin.io)

Join the Fat Cat community and stay updated! The Fat Cat is always watching. 😸

---

## 📜 License
This project is licensed under the **MIT License**.

---

**⚠️ Disclaimer:** This is a meme coin project intended for entertainment and community engagement. Please do your own research before participating. The team is not liable for any losses or risks associated with the use of this token. 🚨
