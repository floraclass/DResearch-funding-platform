# DResearch Funding Protocol

A milestone-driven research funding platform built with Clarity smart contracts on the Stacks blockchain. This system ensures transparent, verifiable, and flexible disbursement of research grants, creating accountability for researchers and assurance for funders.

---

## 🔍 What This Project Solves

Traditional research funding is rigid, opaque, and slow. This platform flips that model—funds are released incrementally based on milestone verification, ensuring that researchers stay on track and funders stay informed.

---

## 🧱 Core Components

### 1. `contract-registry.clar`
- A trusted directory that tracks and verifies contracts across the platform.
  
### 2. `expert-verification.clar`
- Manages expert onboarding and milestone validation workflows.


---

## 🚀 Key Features

### 🎯 Milestone-Based Funding
- **Escrow-controlled disbursement**: Funds are released only after verified progress.
- **Proportional payouts**: Based on milestone achievement.
- **Optional auto-release**: For lower-risk deliverables.

### 🧪 Tailored Research Tracks
- Research types: Scientific, Engineering, Medical, Humanities, etc.
- Custom milestones with adjustable deadlines and funding weights.
- Verification complexity scales with research depth.

### 👨‍🔬 Expert Verification
- Multi-reviewer validation for critical steps.
- Domain-specialized reviewers.
- Transparent comments, timestamped logs.

### 🔄 Built-In Flexibility
- Pivot features allow changes in direction without loss of accountability.
- Dynamic reallocation of remaining funds.
- All changes are logged and reviewable.

---

## ⚙️ How It Works

1. **Proposal Creation**: Researchers outline goals, milestones, timelines, and funding needs.
2. **Funding Phase**: Contributors fund proposals using the platform token.
3. **Milestone Submission**: Researchers submit cryptographic proof of completion.
4. **Verification**: Experts validate complex milestones.
5. **Payouts**: Funds are released upon successful verification.
6. **Pivots**: Researchers may request milestone edits if the research direction evolves.

---

## 🔧 Deployment Guide

### 1. Deploy Contracts (in order)
```bash
contract-registry.clar
research-token.clar
expert-verification.clar
research-funding.clar
```

### 2. Register Contracts
```clarity
(contract-call? .contract-registry register-contract 'SP...research-token "TOKEN" "Research funding token")
(contract-call? .contract-registry register-contract 'SP...expert-verification "EXPERT" "Expert verification system")
(contract-call? .contract-registry register-contract 'SP...research-funding "FUNDING" "Research funding platform")
```

### 3. Configure Token Contract
```clarity
(contract-call? .research-funding set-token-contract 'SP...research-token)
```

---

## 🧪 Usage Examples

### Create a Proposal
```clarity
(contract-call? .research-funding create-proposal 
  "AI in Drug Discovery"
  "Developing ML algorithms to identify viable compounds..." 
  u1 ;; Research type
  u100000000 ;; Tokens requested
  u12345 ;; Expiry
)
```

### Add Milestones
```clarity
(contract-call? .research-funding add-milestone u1 "Phase 1" "Data collection..." u10000 u20000000 false u0)
(contract-call? .research-funding add-milestone u1 "Phase 2" "Model development..." u20000 u50000000 true u2)
```

### Fund a Proposal
```clarity
(contract-call? .research-funding fund-proposal u1 u50000000 'SP...research-token)
```

### Submit Evidence
```clarity
(contract-call? .research-funding submit-milestone-evidence u1 u0 0x...)
```

### Expert Verification
```clarity
(contract-call? .research-funding verify-milestone u1 u1 "Results validated..." 'SP...expert-verification)
```

### Request a Pivot
```clarity
(contract-call? .research-funding request-milestone-pivot 
  u1 u1 "Alternate Approach" 
  "Shifting focus due to preliminary results..." 
  u25000 u60000000)
```

---

## 🛡️ Security Architecture

- **Escrow-based fund custody**  
- **Multi-expert approval for sensitive milestones**  
- **Secure withdrawals and access controls**  
- **Modular design—failure isolation between contracts**

---

## 📈 Roadmap & Future Enhancements

- IPFS/Arweave integration for data proofing  
- DAO-powered governance mechanisms  
- Reputation and incentive systems  
- Cross-chain fund sourcing (e.g., via bridges)  
- Visual dashboards for tracking impact  
- Peer-reviewed NFT certifications

---

## 📦 Prerequisites

- Clarinet v2.11.2 or newer  
- Access to Stacks mainnet or testnet

---

## 📄 License

MIT — Open to build, fork, and deploy freely.

---

Let me know if you want a one-pager version or a version tailored to funders vs developers.
