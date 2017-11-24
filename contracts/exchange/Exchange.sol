/*

  Trustless decentralized digital item & smart contract exchange.

  Written from scratch.

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

  /* Current collected fees, reset upon withdrawal. */
  uint public collectedFees;

  /* The token used to pay exchange fees. */
  ERC20 public exchangeTokenAddress;

  /* All items that have ever been listed. */
  mapping(bytes32 => Item) public items;

  /* Item IDs, stored for accessor convenience. */
  bytes32[] public ids;

  /* All sales that have ever occurred. */
  mapping(bytes32 => Sale) public sales;

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
    /* Item metadata IPFS hash. */
    bytes metadataHash;
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
    /* Auction extra parameter - minimum bid increment for English auctions, decay factor for Dutch auctions. */
    uint auctionExtra;
    /* The escrow provider contract, which is paid a fee to arbitrage escrow disputes and must provide (TODO) specific functions. 0 for no escrow. */
    EscrowProvider escrowProvider;
    /* Whether or not the listing has been removed. */
    bool removed;
  }

  struct Bid {
    /* Address of the bidder. */
    address bidder;
    /* Amount of the bid. */
    uint amount;
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
    /* Sale metadata IPFS hash. */
    bytes metadataHash;
  }

  event ItemListed    (bytes32 id, address seller, Claimable contractAddress, bytes metadataHash, SaleKind saleKind, ERC20 paymentToken, uint price, uint timestamp, uint expirationTime, uint auctionExtra, EscrowProvider escrowProvider);
  event ItemRemoved   (bytes32 id);
  event ItemBidOn     (bytes32 id, address bidder, uint amount, uint timestamp);
  event ItemPurchased (bytes32 id, address buyer, uint price);
  event SaleFinalized (bytes32 id, bytes metadataHash);

  modifier costs (uint amount) {
    require(exchangeTokenAddress.transferFrom(msg.sender, this, amount));
    collectedFees += amount;
    _;
  }

  modifier requiresActiveItem (bytes32 id) {
    require(
      (items[id].seller != address(0)) &&
      (!items[id].removed) &&
      (sales[id].buyer == address(0))
    );
    _;
  }

  function withdrawFees(address dest) onlyOwner {
    require(exchangeTokenAddress.transfer(dest, collectedFees));
    collectedFees = 0;
  }

  function setListFee(uint listFee) onlyOwner {
    feeList = listFee;
  }

  function setBidFee(uint bidFee) onlyOwner {
    feeBid = bidFee;
  }

  function setBuyFee(uint buyFee) onlyOwner {
    feeBuy = buyFee;
  }

  function listItem(Claimable contractAddress, bytes metadataHash, SaleKind saleKind, ERC20 paymentToken, uint price, uint expirationTime, uint auctionExtra, EscrowProvider escrowProvider) costs (feeList) returns (bytes32 id) {
    id = sha3(msg.sender, contractAddress, metadataHash, saleKind, paymentToken, price, now, expirationTime, auctionExtra, escrowProvider);
    require(items[id].seller == address(0));
    if (contractAddress != address(0)) {
      contractAddress.claimOwnership();
    }
    items[id] = Item(msg.sender, contractAddress, metadataHash, saleKind, paymentToken, price, now, expirationTime, auctionExtra, escrowProvider, false);
    ids.push(id);
    ItemListed(id, msg.sender, contractAddress, metadataHash, saleKind, paymentToken, price, now, expirationTime, auctionExtra, escrowProvider);
    return id;
  }

  function removeItem (bytes32 id) requiresActiveItem(id) {
    require(items[id].seller == msg.sender);
    items[id].removed = true;
    ItemRemoved(id);
  }

  function bidOnItem (bytes32 id, uint amount) requiresActiveItem (id) costs (feeBid) {
    /* Must be an English auction that has not yet completed. */
    require(
      (items[id].saleKind == SaleKind.EnglishAuction) &&
      (now < items[id].expirationTime)
      );
    if (topBids[id].bidder == address(0)) {
      /* Amount must be at least the minimum bid. */
      require(amount >= items[id].basePrice);
    } else {
      /* Amount must be at least the last high bid plus the minimum bid increment. */
      require(amount >= topBids[id].amount + items[id].auctionExtra);
      /* Return locked tokens to the previous high bidder. */
      require(items[id].paymentToken.transfer(topBids[id].bidder, topBids[id].amount));
    }
    /* Lock tokens for the new high bidder. */
    require(items[id].paymentToken.transferFrom(msg.sender, this, amount));
    /* Store the new high bid. */
    topBids[id] = Bid(msg.sender, amount, now);
    /* Log the bid event. */
    ItemBidOn(id, msg.sender, amount, now);
  }

  function calculateFinalItemPrice (bytes32 id) public constant requiresActiveItem(id) returns (uint price) {
    if (items[id].saleKind == SaleKind.FixedPrice) {
      return items[id].basePrice;
    } else if (items[id].saleKind == SaleKind.EnglishAuction) {
      require(topBids[id].bidder != address(0));
      return topBids[id].amount;
    } else if (items[id].saleKind == SaleKind.DutchAuction) {
      return items[id].basePrice * (1 - (items[id].auctionExtra * (now - items[id].listingTime) / (items[id].expirationTime - items[id].listingTime)));
    } else {
      throw;
    }
  }

  /* Called by a buyer to purchase an item or finalize an auction they have won. */
  function purchaseItem (bytes32 id) requiresActiveItem (id) costs (feeBuy) {
    if (items[id].saleKind == SaleKind.EnglishAuction) {
      Bid topBid = topBids[id];
      require(
        (msg.sender == topBid.bidder) &&
        (now >= items[id].expirationTime)
      );
      items[id].paymentToken.transfer(msg.sender, topBid.amount);
    } else {
      require(now < items[id].expirationTime);
    }
    uint price = calculateFinalItemPrice(id);
    require(items[id].escrowProvider.holdInEscrow(id, msg.sender, items[id].seller, items[id].paymentToken, price));
    Claimable contractAddress = items[id].contractAddress;
    if (contractAddress != address(0)) {
      contractAddress.transferOwnership(msg.sender);
    }
    sales[id] = Sale(msg.sender, price, now, new bytes(0));
    ItemPurchased(id, msg.sender, price);
  }

  /* Called by the seller of an item to finalize sale to the buyer, linking the IPFS metadata. */
  function finalizeSale (bytes32 id, bytes saleMetadataHash) {
    require(items[id].seller == msg.sender);
    sales[id].metadataHash = saleMetadataHash;
    SaleFinalized(id, saleMetadataHash);
  }

}
