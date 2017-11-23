/*

  << Project Wyvern Exchange >>

  Abstract trustless exchange for digital goods.

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

  /* The token used to pay exchange fees. */
  ERC20 public exchangeTokenAddress;

  /* All sales that have ever been listed. */
  mapping(bytes32 => Sale) public sales; 

  /* Sale IDs, stored for accessor convenience. */
  bytes32[] public saleIDs;

  /* Kind of item being sold - either a secret key (e.g. gift card redemption code) or a smart contract. */
  enum ItemKind { Secret, Contract }

  /* Kind of sale - fixed price or auction. */
  enum SaleKind { FixedPrice, EnglishAuction, DutchAuction }

  /* An item listed for sale on the exchange. */
  struct Sale {
    /* The kind of item. */
    ItemKind itemKind;
    /* Item data; see documentation. */
    bytes32 itemData;
    /* Item metadata - hash of IPFS file and kind of hash used. */
    bytes32 itemMetadataHash;
    uint8 itemMetadataKind;
    uint8 itemMetadataSize;
    /* TODO: Hash to link to encrypted secret after sale completed. */
    /* The kind of sale. */
    SaleKind saleKind;
    /* Token used to pay for the item. */
    ERC20 paymentToken;
    /* Price of the item (tokens). */
    uint price;
    /* Listing timestamp. */
    uint listingTime;
    /* Expiration timestamp - 0 for no expiry. */
    uint expirationTime;
    /* Decay factor, see documentation. 0 for linear Dutch auction / no decay standard. */
    uint decayFactor;
    /* The escrow arbiter address, which is paid a fee to arbitrage escrow disputes and must provide (TODO) specific functions. 0 for no escrow. */
    address escrowArbiter;
    /* Whether or not the item has been sold. */
    bool saleCompleted;
  }

  /* Order of events

    - Item listed
    - Item purchased / auction finished
    - { time period one }
    - buyer releases escrow / buyer does not, this is managed by escrow contracts
    - feedback?

    TODO figure out escrow provider interface

  */ 

}
