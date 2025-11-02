# 🏦 Tokenized Micro-Savings Groups (ROSCA)

A decentralized implementation of Rotating Savings and Credit Associations (ROSCAs) built on the Stacks blockchain using Clarity smart contracts.

## 🌟 What is a ROSCA?

A ROSCA is a traditional savings mechanism where a group of people regularly contribute a fixed amount to a common pool. Each cycle, one member receives the entire pool amount, rotating until everyone has received their turn.

## ✨ Features

- 🔐 **Trustless Operations**: Smart contract handles all transactions automatically
- 💰 **Fixed Contributions**: Set contribution amounts for fair participation  
- 👥 **Flexible Group Sizes**: Support for 2-50 members per ROSCA
- 🎯 **Transparent Winner Selection**: Automated winner selection each cycle
- 📊 **Full Transparency**: All contributions and payouts are on-chain
- 🔄 **Multi-Cycle Support**: Complete rotation through all members

## 🚀 Getting Started

### Prerequisites

- Clarinet installed
- Stacks wallet with STX tokens
- Basic understanding of Clarity smart contracts

### 📋 Core Functions

#### Creating a ROSCA
```clarity
(contract-call? .rosca create-rosca contribution-amount max-members cycle-duration)
```

#### Joining a ROSCA
```clarity
(contract-call? .rosca join-rosca rosca-id)
```

#### Making Contributions
```clarity
(contract-call? .rosca contribute rosca-id)
```

#### Selecting Winners
```clarity
(contract-call? .rosca select-winner rosca-id)
```

#### Claiming Winnings
```clarity
(contract-call? .rosca claim-winnings rosca-id cycle)
```

## 🎮 Usage Example

### 1️⃣ Create a New ROSCA
```bash
clarinet console
```
```clarity
(contract-call? .rosca create-rosca u1000000 u5 u144)
```
*Creates a ROSCA with 1 STX contributions, 5 max members, 144 block cycle duration*

### 2️⃣ Join an Existing ROSCA
```clarity
(contract-call? .rosca join-rosca u1)
```

### 3️⃣ Contribute to Current Cycle
```clarity
(contract-call? .rosca contribute u1)
```

### 4️⃣ Check ROSCA Details
```clarity
(contract-call? .rosca get-rosca u1)
```

### 5️⃣ View Your Membership
```clarity
(contract-call? .rosca get-rosca-member u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 📊 Read-Only Functions

- `get-rosca` - Get ROSCA details
- `get-rosca-member` - Get member information  
- `get-cycle-contribution` - Check contribution status
- `get-cycle-winner` - View cycle winner details
- `get-rosca-balance` - Check ROSCA pool balance
- `get-total-roscas` - Total number of ROSCAs created

## 🔧 Contract Architecture

### Data Structures

- **ROSCAs**: Main ROSCA configuration and state
- **Members**: Individual member participation data
- **Contributions**: Per-cycle contribution tracking
- **Winners**: Cycle winner records and claim status
- **Balances**: ROSCA pool balance management

### Key Parameters

- **Contribution Amount**: Fixed STX amount per cycle
- **Max Members**: Maximum participants (2-50)
- **Cycle Duration**: Blocks between cycles
- **Current Cycle**: Active cycle number
- **Total Cycles**: Equals max members for full rotation

## 🛡️ Security Features

- Member verification before actions
- Duplicate contribution prevention
- Winner verification for claims
- Balance validation before payouts
- Creator-only cycle advancement

## 🧪 Testing

```bash
clarinet test
```

## 📝 License

MIT License - Build amazing things! 🚀

## 🤝 Contributing

Contributions welcome! Please feel free to submit pull requests or open issues for improvements.

---

*Built with ❤
