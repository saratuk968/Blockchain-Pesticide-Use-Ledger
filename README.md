# 🌱 Blockchain Pesticide Use Ledger

A Clarity smart contract for tracking pesticide applications on farms to ensure compliance with organic farming standards and maintain transparent agricultural records.

## 📋 Overview

This smart contract provides a comprehensive system for:
- 🚜 Farm registration and management
- 🧪 Pesticide application tracking
- ✅ Organic certification compliance monitoring
- 👨‍🔬 Inspector verification system
- 📊 Transparent audit trails

## 🚀 Features

### Farm Management
- Register farms with location, size, and organic certification status
- Update organic certification status
- Track multiple farms per owner

### Pesticide Tracking
- Record detailed pesticide applications
- Track concentration, quantity, and application areas
- Monitor weather conditions during application
- Automatic organic compliance checking

### Verification System
- Authorized inspector verification
- Application approval workflow
- Compliance monitoring for organic farms

### Data Transparency
- Public read access to farm and application data
- Recent application queries
- Organic compliance status checking

## 📖 Usage Instructions

### 1. Register a Farm
```clarity
(contract-call? .blockchain-pesticide-use-ledger register-farm 
    "Green Valley Farm" 
    "California, USA" 
    u100 
    true)
```

### 2. Add Approved Pesticides (Contract Owner Only)
```clarity
(contract-call? .blockchain-pesticide-use-ledger add-approved-pesticide 
    "Organic Neem Oil" 
    "Azadirachtin" 
    true 
    u1000 
    u7)
```

### 3. Record Pesticide Application
```clarity
(contract-call? .blockchain-pesticide-use-ledger record-pesticide-application 
    u1 
    "Organic Neem Oil" 
    "Insecticide" 
    u500 
    u10 
    "Tomatoes" 
    u5 
    "Sunny, 22C, Light wind")
```

### 4. Authorize Inspector (Contract Owner Only)
```clarity
(contract-call? .blockchain-pesticide-use-ledger authorize-inspector 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
    "John Smith" 
    "CERT-2024-001")
```

### 5. Verify Application (Inspector Only)
```clarity
(contract-call? .blockchain-pesticide-use-ledger verify-application u1)
```

## 🔍 Query Functions

### Get Farm Information
```clarity
(contract-call? .blockchain-pesticide-use-ledger get-farm u1)
```

### Check Organic Compliance
```clarity
(contract-call? .blockchain-pesticide-use-ledger check-organic-compliance u1)
```

### Get Recent Applications
```clarity
(contract-call? .blockchain-pesticide-use-ledger get-recent-applications u1 u30)
```

### Get Application Details
```clarity
(contract-call? .blockchain-pesticide-use-ledger get-application u1)
```

## 🏗️ Contract Structure

### Data Maps
- **farms**: Store farm registration details
- **farm-owners**: Link owners to their farms
- **pesticide-applications**: Record all pesticide applications
- **farm-applications**: Link farms to their applications
- **approved-pesticides**: Maintain approved pesticide
