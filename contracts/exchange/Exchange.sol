/*

  << Project Wyvern Exchange >>

  Trustless decentralized digital item exchange.

  Written from scratch.

*/

/*

  TODO:
    - Think about auction format, gas price races

*/

pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/ERC20.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/ownership/Claimable.sol';

import './EscrowProvider.sol';

contract Exchange is Ownable {

  /* The owner address of the exchange (a) can withdraw fees periodically and (b) can change the fee amounts, escrow settings. */

  /* The fee required to list an item for sale. */
  uint public feeList;
  
  /* The fee required to bid on an item. */
  uint public feeBid;

  /* The fee required to buy an item. */
  uint public feeBuy;

  /* Current collected fees. */
  uint public collectedFees;

  /* The token used to pay exchange fees. */
  ERC20 public exchangeTokenAddress;

  /* All items that have ever been listed. */
  mapping(bytes32 => Item) public items;

  /* Item IDs, stored for accessor convenience. */
  bytes32[] public ids;

  /* All sales that have ever occurred. */
  mapping(bytes32 => Sale) public sales;

  /* Metadata for all completed sales. */
  mapping(bytes32 => SaleMetadata) public saleMetadata;

  /* Top bids for all English auctions. */
  mapping(bytes32 => Bid) public topBids;

  /* Kind of sale - fixed price or auction. */
  enum SaleKind { FixedPrice, EnglishAuction, DutchAuction }

  /* An item listed for sale on the exchange. */
  struct Item {
    /* The address selling the item. */
    address seller;
    /* Item contract - a value of 0 means no contract is being sold. */
    Claimable contractAddress;
    /* Item metadata - hash of IPFS file and kind of hash used. */
    bytes32 metadataHash;
    uint8 metadataKind;
    uint8 metadataSize;
    /* TODO: Hash to link to encrypted secret after sale completed. */
    /* The kind of sale. */
    SaleKind saleKind;
    /* Token used to pay for the item. */
    ERC20 paymentToken;
    /* Base price of the item (tokens). */
    uint basePrice;
    /* Listing timestamp. */
    uint listingTime;
    /* Expiration timestamp - 0 for no expiry. */
    uint expirationTime;
    /* Decay factor, see documentation. */
    uint decayFactor;
    /* The escrow provider contract, which is paid a fee to arbitrage escrow disputes and must provide (TODO) specific functions. 0 for no escrow. */
    EscrowProvider escrowProvider;
    /* Whether or not the listing has been removed. */
    bool removed;
  }

  struct Bid {
    /* Amount of the bid. */
    uint amount;
    /* Address of the bidder. */
    address bidder;
    /* Timestamp of bid placement. */
    uint timestamp;
  }

  struct Sale {
    /* Address of the buyer. */
    address buyer;
    /* Final sale price. */
    uint price;
    /* Timestamp of purchase. */
    uint timestamp;
  }

  struct SaleMetadata {
    bytes32 hash;
    uint8 kind;
    uint8 size;
  }

  modifier costs (uint amount) {
    require(exchangeTokenAddress.transferFrom(msg.sender, this, amount));
    collectedFees += amount;
    _;
  }

  modifier requiresActiveItem (bytes32 id) {
    require(
      (items[id].seller != address(0)) &&
      (!items[id].removed)
    );
    _;
  }

  function listItem(Claimable contractAddress, bytes32 itemMetadataHash, uint8 itemMetadataKind, uint8 itemMetadataSize, SaleKind saleKind, ERC20 paymentToken, uint price, uint expirationTime, uint decayFactor, EscrowProvider escrowProvider) costs (feeList) returns (bytes32 id) {
    /* TODO: Think about preventing duplicates. */
    id = sha3(msg.sender, contractAddress, itemMetadataHash, itemMetadataKind, itemMetadataSize, saleKind, paymentToken, price, now, expirationTime, decayFactor, escrowProvider);
    require(items[id].seller == address(0));
    if (contractAddress != address(0)) {
      contractAddress.claimOwnership();
    }
    items[id] = Item(msg.sender, contractAddress, itemMetadataHash, itemMetadataKind, itemMetadataSize, saleKind, paymentToken, price, now, expirationTime, decayFactor, escrowProvider, false);
    ids.push(id);
    return id;
  }

  function removeItem (bytes32 id) {
    require(
      (items[id].seller == msg.sender) &&
      (!items[id].removed)
      );
    items[id].removed = true;
  }

  function bidOnItem (bytes32 id) requiresActiveItem (id) costs (feeBid) {
    require(items[id].saleKind == SaleKind.EnglishAuction);
    /* TODO */
  }

  /* Called by a buyer to purchase an item */
  function purchaseItem (bytes32 id) requiresActiveItem (id) costs (feeBuy) {
    /* TODO Deal with English auction, calculate price for Dutch auction. */
    uint price = items[id].basePrice;
    require(items[id].escrowProvider.holdInEscrow(id, msg.sender, items[id].seller, items[id].paymentToken, price));
    Claimable contractAddress = items[id].contractAddress;
    if (contractAddress != address(0)) {
      contractAddress.transferOwnership(msg.sender);
    }
    sales[id] = Sale(msg.sender, price, now); 
  }

  /* Called by the seller of an item to finalize sale to the buyer. */
  function finalizeSale (bytes32 id, bytes32 saleMetadataHash, uint8 saleMetadataKind, uint8 saleMetadataSize) {
    /* TODO */
  }

}
