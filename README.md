# P2P Platform Contract

## Table of Contents

1. [Introduction](#introduction)
2. [Dependencies](#dependencies)
3. [Implementation](#implementation)
4. [Spring Boot Site](#spring-boot-site)
5. [Known Limitations](#known-limitations)
6. [Getting Started](#getting-started)
7. [Makefile Guide](#makefile-guide)
8. [Terminal execution](#running-terminal-panes)

---

## Introduction

This repository contains a solution that includes a Solidity smart contract, unit tests, a Makefile for automation, and a Spring Boot site for backend integration with Foundry's local Anvil EVM node.

---

## Dependencies

To set up the project, you'll need to install the following dependencies:

- **Foundry**: Download and install from [here](https://getfoundry.sh/)
- **Make**
- **JDK**
- **Solidity Compiler**: Version 0.8.20
- **Web3j CLI Tooling**: For Ethereum Java integration
- **Maven**: site build toolchain
---

## Implementation

### Smart Contract

The smart contract is implemented using Solidity and adheres to the latest best practices. It utilizes the OpenZeppelin library v5.0 for upgradability and other features. The contract performs low-level calls for transfers and employs custom errors over traditional reverts or modifiers. The code is optimized for gas efficiency and YUL assembly did not offer better efficiency.

### Spring Boot Site

The Spring Boot application is integrated with Web3j to interact with the Ethereum network. It provides RESTful APIs for depositing and fetching balances. Here's a code snippet demonstrating a deposit operation:

```java
P2PEth contract = P2PEth.load(contractAddress, web3j, credentials, contractGasProvider);
BigInteger weiValue = amount.multiply(BigInteger.valueOf(1000000000000000000L));
TransactionReceipt transactionReceipt = contract.deposit(weiValue).send();
```

Logging has been incorporated to monitor interactions with Foundry's Anvil EVM node.

---

## Known Limitations

- The contract is tested with 11 unit tests, but a production implementation would require more.
- The Spring Boot site is a modified sample and code looks it.
- Due to Web3j limitation, Solidity up to version 0.8.20 is supported.
- The Anvil private key is hardcoded and non-sharded.

---

## Getting Started

To get started, use the Makefile as a guide. Execute the following Makefile targets:

- `build`
- `test`
- `anvil`
- `full-deploy`
- `version`
- `company-address`
- `balance`
- `deposit`

For integration testing, ensure both Anvil and the Spring Boot site are running. Use `make deposit amount=1` to deposit 1 Ether and check the balance.

---

## Makefile Guide

The Makefile includes various targets for building, testing, and deploying the contract. It also provides utilities for formatting the code, generating gas reports, and more. For a detailed list, refer to the Makefile in the repository.

---

## Running terminal panes

```bash
# terminal shell pane
make deposit amount=1
Deposit successful%
```
```bash
# anvil pane
eth_sendRawTransaction

    Transaction: 0x7897365fba2cff01deec2e8205ac9be0c8dc72584533eec98557c1fe0296b3f6
    Gas used: 32743

    Block Number: 3
    Block Hash: 0x3db27c9d4b5ba443ccb5dd627d7740c658150c38fa07d426f9adb8fa668d0c94
    Block Time: "Tue, 17 Oct 2023 18:30:58 +0000"
```
```bash
# site pane
2023-10-17T21:30:58.489+03:00  INFO 95774 --- [nio-8080-exec-2] com.example.restservice.EthController    : Transaction receipt: TransactionReceipt{transactionHash='0x7897365fba2cff01deec2e8205ac9be0c8dc72584533eec98557c1fe0296b3f6', transactionIndex='0x0', blockHash='0x3db27c9d4b5ba443ccb5dd627d7740c658150c38fa07d426f9adb8fa668d0c94', blockNumber='0x3', cumulativeGasUsed='0x7fe7', gasUsed='0x7fe7', contractAddress='null', root='null', status='0x1', from='0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266', to='0xe7f1725e7734ce288f8367e1bb143e90bb3f0512', logs=[Log{removed=false, logIndex='0x0', transactionIndex='0x0', transactionHash='0x7897365fba2cff01deec2e8205ac9be0c8dc72584533eec98557c1fe0296b3f6', blockHash='0x3db27c9d4b5ba443ccb5dd627d7740c658150c38fa07d426f9adb8fa668d0c94', blockNumber='0x3', address='0xe7f1725e7734ce288f8367e1bb143e90bb3f0512', data='0x0000000000000000000000000000000000000000000000000de0b6b3a7640000', type='null', topics=[0x2da466a7b24304f47e87fa2e1e5a81b9831ce54fec19055ce277ca2f39ba42c4, 0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266]}], logsBloom='0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000100000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000001000000000002000000000000000000000000040000000000000000000000000000000000000000000800000000000000000', revertReason='null', type='null', effectiveGasPrice='0xf4610900'}
```