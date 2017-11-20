## Project Wyvern Ethereum Smart Contracts

[![https://badges.frapsoft.com/os/mit/mit.svg?v=102](https://badges.frapsoft.com/os/mit/mit.svg?v=102)](https://opensource.org/licenses/MIT) [![Build Status](https://travis-ci.org/protinam/wyvern-ethereum.svg?branch=master)](https://travis-ci.org/protinam/wyvern-ethereum)

### Synopsis

*Cryptocurrency for gamers, by gamers.*

These are the official Ethereum smart contracts for the Wyvern ERC20 token (WYV), the Wyvern Exchange, and the Wyvern DAO. For general information on the Wyvern project, please see [the official website](https://projectwyvern.com).

### Development Information

#### Setup

[Node >= v6.9.1](https://nodejs.org/en/) and [Yarn](https://yarnpkg.com/en/) required.

Before any development, install the required NPM dependencies:

```bash
yarn
```

#### Testing

Start Ethereum's testrpc tool to provide a Web3 interface (leave this running):

```bash
yarn run testrpc
```

Compile the latest smart contracts:

```bash
yarn run compile
```

Run the testsuite against the simulated network:

```bash
yarn run test
```

#### Contributing

Contributions welcome! Please use GitHub issues for suggestions/concerns - if you prefer to express your intentions in code, feel free to submit a pull request.
