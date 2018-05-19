Wyvern Protocol v2.1 "Fafnir" Audit Specification
-------------------------------------------------

### Version 2.1 Note

This is version 2.1 of the Wyvern Protocol, which comprises relatively minor changes from v1. If you audited the previous version, you may find it more efficient to simply view the contract code diff. This can easily be done by running `git diff 969a69f465b662abfde35815fa45c2b94736cf99 contracts` from the repository root.

Versions 1 and 2 of the protocol are operating live on the Ethereum mainnet, and have already been used to trade [virtual items](https://exchange.projectwyvern.com/orders/0xa2c40276fbb97a87f464336cfbe97d00bcee1da0f491dabb5d935370c589aea8), [digital kittens](https://exchange.projectwyvern.com/orders/0x78fc4f8df1263000495c6dc952b87210cf6198fc254decc7640275e2de80719d), and even [a smart contract](https://exchange.projectwyvern.com/orders/0x43186f200cb8e687d9d2c15d538fb6742f32f9a454430447834d1319039ef214). Playing around with [the Wyvern Exchange](https://exchange.projectwyvern.com/) may help you understand the high-level goals of the protocol; however, please note that the present incarnation of the Exchange UI uses but a small subset of the functionality the protocol smart contracts incorporate. You can also read the [Contract Architecture](https://wiki.projectwyvern.com/contract-architecture) page on the Project Wyvern wiki.

#### Summary of changes from v2

- Heavy EVM optimization of masked bytecode replacement (mostly: performed word-wise rather than byte-wise) and byte array operations. See `contracts/common/ArrayUtils.sol`, mostly rewritten from v2.
- Updated to solc v0.23 (emit before events, some minor syntax changes)
- Updated `zeppelin-solidity` dependency
- Manual (assembly) order hash calculation

### Full Audit Specification

The Wyvern Protocol is an Ethereum framework for the exchange of nonfungible digital assets. Protocol users - human-operated Ethereum accounts or other Ethereum smart contracts - place orders expressing the intent to sell or buy a particular asset or any asset with certain characteristics. The protocol's job is to match buyer and seller intent on-chain such that the asset transfer and payment happen atomically. The protocol functions solely as a settlement layer - orderbook storage and matching algorithms are left to off-chain infrastructure.

The protocol is representation-agnostic: it supports any asset that can be represented on the Ethereum chain (i.e., transferred in an Ethereum transaction or a sequence of transactions). Users will be able to buy and sell anything from CryptoKitties to ENS names to smart contracts themselves. The protocol "knows nothing" about asset representations - instead, buyer and seller intents are specified as functions over the space of Ethereum transactions, as follows:

  - Buy-side and sell-side orders each provide calldata (bytes) - for a sell-side order, the state transition for sale, for a buy-side order, the state transition to be bought. Along with the calldata, orders provide `replacementPattern`: a bytemask indicating which bytes of the calldata can be changed (e.g. NFT destination address). When a buy-side and sell-side order are matched, the desired calldatas are unified, masked with the bytemasks, and checked for agreement. This alone is enough to implement common simple state transitions, such as "transfer my CryptoKitty to any address" or "buy any of this kind of nonfungible token".
  - Orders of either side can optionally specify a static (no state modification) callback function, which receives configurable data along with the actual calldata as a parameter. This allows for arbitrary transaction validation functions. For example, a buy-sider order could express the intent to buy any CryptoKitty with a particular set of characteristics (checked in the static call), or a sell-side order could express the intent to sell any of three ENS names, but not two others. Use of the EVM's STATICCALL opcode, added in Ethereum Metropolis, allows the static calldata to be safely specified separately and thus this kind of matching to happen correctly - that is to say, wherever the two validation callbacks mapping Ethereum transactions to booleans intersect.

The following contracts are within the scope of this audit (and together comprise complete functionality of the protocol):

#### WyvernAtomicizer.sol

Top-level atomicizer library. Provides a simple method to serialize multiple transactions at runtime (all-or-nothing; if one fails all are reverted).

#### WyvernTokenTransferProxy.sol

Top-level token transfer proxy contract, inherits from TokenTransferProxy.sol

#### WyvernProxyRegistry.sol

Top-level proxy registry contract, inherits from ProxyRegistry.sol. Facilitates a once-only immediate authentication of a contract to access user-created proxies.

#### WyvernDAOProxy.sol

Top-level delegate proxy contract, inherits from DelegateProxy.

#### DelegateProxy.sol

Simple, single-owner DELEGATECALL proxy contract. Designed to allow accounts / contracts which can only issue CALLs to make use of the Atomicizer library to serialize transactions.

#### TokenTransferProxy.sol

Simple proxy contract to authenticate ERC20 `transferFrom` calls. Uses the authentication table of a `ProxyRegistry` contract (so users will only need to call ERC20 `approve` once for all future protocol versions).

#### AuthenticatedProxy.sol

Proxy contract deployed by protocol users to hold assets on their behalf and transfer them when conditions for order matching are met. Facilitates arbitrary passthrough CALLs or DELEGATECALLs, performed either by the user who created the contract or by the Exchange contract, authenticated through the ProxyRegistry contract, when the conditions for order matching are met.

#### ProxyRegistry.sol

Proxy registry contract. Keeps a mapping of users to proxy contracts so the Exchange contract can look up the proxy contract for a particular order. Separate from the Exchange (a) to reduce Exchange attack surface and (b) to facilitate Exchange protocol upgrades, such as supporting a different kind of Dutch auction, without requiring that users transfer assets to new proxy contracts. The Registry will be controlled by the Wyvern DAO, which can authenticate new protocol versions after a mandatory delay period to prevent against possible economic attacks.

#### WyvernExchange.sol

Top-level exchange contract, inherits from Exchange.sol. No independent functionality.

#### ArrayUtils.sol

Utility library. Facilities masked byte array replacement and byte array equality comparision. Used by ExchangeCore.

#### ReentrancyGuarded.sol

Utility library. Function modifier to guard a function with a contract-global reentrancy prevention lock. Used by ExchangeCore.

#### TokenRecipient.sol

Utility library. Logs receipt of tokens and implements the default payable function. Used by AuthenticatedProxy.

#### SaleKindInterface.sol

Utility library. Facilitates validation of order parameters (fixed price / Dutch auction & timestamps) and calculates final order prices when orders are matched.

#### Exchange.sol

Public interface library, inherits from ExchangeCore. No independent state-modifying functionality. Exposes internal ExchangeCore functions with struct conversions (the internal functions use structs, external encoding for which the Solidity encoder does not yet support) and exposes a few convenience read-only methods.

#### ExchangeCore.sol

Core protocol contract. Facilitates order approval, order validation, order cancellation, and atomic order matching. The ExchangeCore contract holds no tokens or assets itself - ERC20 tokens are held by protocol users (who must call `approve`) and nonfungible assets are held by AuthenticatedProxy contracts (from which the users can withdraw the assets at any time).

Deployed contracts on Rinkeby:

[Wyvern Exchange](https://rinkeby.etherscan.io/address/0x838d2403a061b459e15b494e78acae2bb3333dda)

[Wyvern Atomicizer](https://rinkeby.etherscan.io/address/0x6bec0bcf2834d34454942964b7b6f0537032546e)

[Wyvern DAO Proxy](https://rinkeby.etherscan.io/address/0xb44cc6d88168852f77755982936a20b00d971415)

[Wyvern Token Transfer Proxy](https://rinkeby.etherscan.io/address/0x03851346f00bc9166623197cce189e68d7f847dc)

[Wyvern Proxy Registry](https://rinkeby.etherscan.io/address/0xb7297a9ae13e73e36069413f13d37c79b97db773)

Note that the [wyvern-ethereum](https://github.com/projectwyvern/wyvern-ethereum) repository also contains contracts for the WYV token and the Wyvern DAO. Those contracts have already been deployed and are not within the scope of this audit (nor are they relevant to the functionality or correctness of the Wyvern Protocol).

Individual function documentation can be found in the source code, written using Ethereum's NatSpec format. A rendered version of the documentation is also available at [docs.projectwyvern.com](https://docs.projectwyvern.com).

For additional background on the Wyvern project and the motivation behind it, you may find [the whitepaper](https://github.com/ProjectWyvern/wyvern-protocol/raw/master/build/whitepaper.pdf) useful - however, the whitepaper's description of the protocol may not be entirely up-to-date; the smart contract versions submitted to the audit are canonical.
