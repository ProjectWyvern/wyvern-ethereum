![Project Wyvern Logo](https://media.githubusercontent.com/media/ProjectWyvern/wyvern-branding/master/logo/logo-square-red-transparent-200x200.png?raw=true "Project Wyvern Logo")

## Project Wyvern Ethereum Smart Contracts

[![https://badges.frapsoft.com/os/mit/mit.svg?v=102](https://badges.frapsoft.com/os/mit/mit.svg?v=102)](https://opensource.org/licenses/MIT) [![Build Status](https://travis-ci.org/ProjectWyvern/wyvern-ethereum.svg?branch=master)](https://travis-ci.org/ProjectWyvern/wyvern-ethereum) [![Coverage Status](https://coveralls.io/repos/github/ProjectWyvern/wyvern-ethereum/badge.svg?branch=master)](https://coveralls.io/github/ProjectWyvern/wyvern-ethereum?branch=master)

### Synopsis

*Autonomously governed decentralized digital asset exchange.*

These are the Ethereum smart contracts for the Wyvern Protocol, the Wyvern ERC20 token (WYV), and the Wyvern DAO. For general information on the Wyvern project, please see [the website](https://projectwyvern.com).

### Deployed Contracts

*Please note: correct deployed contract addresses will always be in config.json. If you wish to import this repository directly, please use that file. The addresses in Truffle build output are not necessarily accurate.*

#### Mainnet

[Wyvern Exchange](https://etherscan.io/address/wyvernexchange.eth)

[Wyvern Proxy Registry](https://etherscan.io/address/wyvernproxyregistry.eth)

[Wyvern Token](https://etherscan.io/address/wyverntoken.eth)

[Wyvern DAO](https://etherscan.io/address/wyverndao.eth)

#### Rinkeby Testnet

[Wyvern Exchange](https://rinkeby.etherscan.io/address/0xdca1fbe9f9469613aa2101b5e797226a9b586297)

[Wyvern Atomicizer](https://rinkeby.etherscan.io/address/0x90b0c4d26520be6a941954d565f90ecf2991d8a7)

[Wyvern DAO Proxy](https://rinkeby.etherscan.io/address/0x32f51cefe7d1cac49334b7267da6ae7a127526da)

[Wyvern Token Transfer Proxy](https://rinkeby.etherscan.io/address/0xb89f6ac677a7530d9d6649d299350be90a50ad1e)

[Wyvern Proxy Registry](https://rinkeby.etherscan.io/address/0xeceaa7453a77bfe339b25d9d9e91009cde71c768)

[Wyvern Token](https://rinkeby.etherscan.io/address/0xd1be358dab323802a3c469b0787476fdcb8af5d6)

[Wyvern DAO](https://rinkeby.etherscan.io/address/0x1b4c767502d01deee83af491c946b469e0620e30)

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
yarn testrpc
```

Compile the latest smart contracts:

```bash
yarn compile
```

Run the testsuite against the simulated network:

```bash
yarn test
```

Make sure to lint the Solidity files once you're done:

```bash
yarn lint
```

#### Generating Documentation

Install the dependencies:

```bash
cd doxity
yarn
cd ..
```

Autogenerate documentation from Ethereum Natspec using [Doxity](https://github.com/DigixGlobal/doxity):

```bash
yarn doc
```

Final output will be written to [docs](docs), which will be automatically published on push to GitHub Pages at [docs.projectwyvern.com](https://docs.projectwyvern.com).

#### Misc

Run automated smart contract analysis (requires [Oyente](https://github.com/melonproject/oyente) and [Mythril](https://github.com/ConsenSys/mythril)):

```bash
yarn analyze
```

Flatten contract source (for e.g. Etherscan verification, requires [solidity-flattener](https://github.com/BlockCatIO/solidity-flattener) to be installed):
```bash
yarn flatten
```

#### Contributing

Contributions welcome! Please use GitHub issues for suggestions/concerns - if you prefer to express your intentions in code, feel free to submit a pull request.
