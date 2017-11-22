/*

  << Project Wyvern Exchange >>

  Abstract trustless digital good exchange.

  Written from scratch.

*/

/*

  TODO:
    - Ability to buy/sell/auction "Ownable" assets.
    - Require hash commitments to digital items, could be revealed in dispute process out-of-band.
    - Included escrow system (maybe v2 - simple version first? - Wyvern DAO escrow?).
    - Seller must transfer out-of-band, can automatically reveal to release escrow after time delay => actually this is trustless? Can encrypt secrets to buyer... What about validity disputes? Escrow system / arbitration?
    - Think about auction format, gas price races

  Maybe: 
    - Add upgradability ("redirect all calls except core voting to address X") - will this allow new function declarations in future versions? - by set delegatecall?

*/

pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/ERC20.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Exchange is Ownable {

  /* The owner address of the exchange (a) can withdraw fees periodically and (b) can change the fee amounts, escrow settings. */

  /* The fee required to list an item for sale. */
  uint public feeSell;
  
  /* The fee required to bid on an item. */
  uint public feeBid;

  /* The fee required to buy an item. */
  uint public feeBuy;

  /* The time δ before automatic escrow release to seller with hash proof (seconds). */
  uint public automaticReleaseTime;
 
  /* The token used to pay exchange fees. */
  ERC20 public exchangeTokenAddress;

  /* All items that have ever been listed. */
  mapping(bytes32 => Item) public items; 

  /* Item IDs, stored for accessor convenience. */
  bytes32[] public itemIDs;

  /* Kind of item being sold - either a secret key (e.g. gift card redemption code) or a smart contract. */
  enum ItemKind { Secret, Contract }

  struct Item {
    ItemKind kind;
    bytes32 secretHashOrContractAddress;
  }

  /* Kind of sale - fixed price or auction. */
  enum SaleKind { FixedPrice, EnglishAuction, DutchAuction }

  struct Sale {
    Item item;
    SaleKind kind;
    ERC20 token;
    uint price;
    uint listingTime;
    uint expirationTime;
    /* The escrow arbiter address, which is paid a fee to arbitrage escrow disputes and must provide (TODO) specific functions. 0 for no escrow? */
    address escrowArbiter;
  }

  function Exchange(ERC20 tokenAddress) {
    exchangeTokenAddress = tokenAddress;
  }

}
