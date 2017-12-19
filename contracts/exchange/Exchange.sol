/*

  Decentralized digital item exchange.

  Written from scratch.

*/

pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

import "./EscrowProvider.sol";
import "./SaleKindInterface.sol";
import "./NonFungibleAssetInterface.sol";

/**
 * @title Exchange
 * @author Project Wyvern Developers
 */
contract Exchange is Ownable {

    /* The owner address of the exchange (a) can withdraw fees periodically and (b) can change the fee amounts, escrow settings. */

    /* Public benefit address. */
    address public publicBeneficiary; 

    /* The fee required to list an item for sale. */
    uint public feeList;
  
    /* The fee required to bid on an item. */
    uint public feeBid;

    /* The fee required to buy an item. */
    uint public feeBuy;

    /* Transaction percentage fee paid to contract owner, in basis points. */
    uint public feeOwner;

    /* Transaction percentage fee paid to public beneficiary, in basis points. */
    uint public feePublicBenefit;

    /* Transaction percentage fee paid to frontend, in basis points. */
    uint public feeFrontend;

    /* Current collected fees available for withdrawal, by owner, by token. */
    mapping(address => mapping(address => uint)) collectedFees;

    /* The token used to pay exchange fees. */
    ERC20 public exchangeTokenAddress;

    /* All items that have ever been listed. */
    mapping(bytes32 => Item) public items;

    /* Item IDs, stored for accessor convenience. */
    bytes32[] public ids;

    /* All sales that have ever occurred. */
    mapping(bytes32 => Sale) public sales;

    /* Top bids for all bid-supporting auctions. */
    mapping(bytes32 => SaleKindInterface.Bid) public topBids;

    /* ERC20 whitelist. */
    mapping(address => bool) erc20Whitelist;

    /* Escrow provider whitelist. */
    mapping(address => bool) escrowProviderWhitelist;

    /* An item listed for sale on the exchange. */
    struct Item {
        /* The address selling the item. */
        address seller;
        /* Item contract nonfungible kind. */
        NonFungibleAssetInterface.NonFungibleAssetKind assetKind; 
        /* Item contract - a value of 0 means no contract is being sold. */
        address contractAddress;
        /* Item contract nonfungible extra (token ID). */
        uint assetExtra;
        /* Item metadata IPFS hash. */
        bytes metadataHash;
        /* The kind of sale. */
        SaleKindInterface.SaleKind saleKind;
        /* Token used to pay for the item. */
        ERC20 paymentToken;
        /* Base price of the item (tokens). */
        uint basePrice;
        /* Listing timestamp. */
        uint listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint expirationTime;
        /* Auction extra parameter - minimum bid increment for English auctions, decay factor for Dutch auctions. */
        uint extra;
        /* The escrow provider contract, which is paid a fee to arbitrage escrow disputes and must provide (TODO) specific functions. 0 for no escrow. */
        EscrowProvider escrowProvider;
        /* Whether or not the listing has been removed. */
        bool removed;
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

    event ItemListed    (bytes32 id, address seller, NonFungibleAssetInterface.NonFungibleAssetKind assetKind, address contractAddress, uint assetExtra, bytes metadataHash, SaleKindInterface.SaleKind saleKind, ERC20 paymentToken, uint price, uint timestamp, uint expirationTime, uint extra, EscrowProvider escrowProvider);
    event ItemRemoved   (bytes32 id);
    event ItemBidOn     (bytes32 id, address bidder, uint amount, uint timestamp);
    event ItemPurchased (bytes32 id, address buyer, uint price);
    event SaleFinalized (bytes32 id, bytes metadataHash);
    event PublicBeneficiaryChanged (address indexed newAddress);

    modifier requiresValidToken(ERC20 erc20) {
        require(erc20Whitelist[erc20]);
        _;
    }

    modifier requiresValidEscrowProvider(EscrowProvider escrowProvider) {
        require(escrowProviderWhitelist[escrowProvider]);
        _;
    }

    modifier requiresActiveItem (bytes32 id) {
        require((items[id].seller != address(0)) && (!items[id].removed) && (sales[id].buyer == address(0)));
        _;
    }

    modifier costs (uint amount) {
        require(exchangeTokenAddress.transferFrom(msg.sender, this, amount));
        collectedFees[owner][exchangeTokenAddress] += amount;
        _;
    }

    function setPublicBeneficiary(address newAddress) onlyOwner public {
        publicBeneficiary = newAddress;
        PublicBeneficiaryChanged(newAddress);
    }

    function withdrawFees(address dest, address token) public {
        uint amount = collectedFees[msg.sender][token];
        collectedFees[msg.sender][token] = 0;
        require(ERC20(token).transfer(dest, amount));
    }

    function setFees(uint listFee, uint bidFee, uint buyFee, uint ownerFee, uint publicBenefitFee, uint frontendFee) onlyOwner public {
        feeList = listFee;
        feeBid = bidFee;
        feeBuy = buyFee;
        feeOwner = ownerFee;
        feePublicBenefit = publicBenefitFee;
        feeFrontend = frontendFee;
    }

    function listItem(NonFungibleAssetInterface.NonFungibleAssetKind assetKind, address contractAddress, uint assetExtra, bytes metadataHash, SaleKindInterface.SaleKind saleKind, ERC20 paymentToken, uint price, uint expirationTime, uint extra, EscrowProvider escrowProvider) public costs (feeList) returns (bytes32 id) {
        id = keccak256(msg.sender, assetKind, contractAddress, assetExtra, metadataHash, saleKind, paymentToken, price, now, expirationTime, extra, escrowProvider);
        require(items[id].seller == address(0));
        NonFungibleAssetInterface.claimOwnership(assetKind, contractAddress, assetExtra);
        items[id] = Item(msg.sender, assetKind, contractAddress, assetExtra, metadataHash, saleKind, paymentToken, price, now, expirationTime, extra, escrowProvider, false);
        ids.push(id);
        ItemListed(id, msg.sender, assetKind, contractAddress, assetExtra, metadataHash, saleKind, paymentToken, price, now, expirationTime, extra, escrowProvider);
        return id;
    }

    function removeItem (bytes32 id) public requiresActiveItem(id) {
        Item storage item = items[id];
        require(item.seller == msg.sender);
        item.removed = true;
        ItemRemoved(id);
    }

    function bidOnItem (bytes32 id, uint amount) public requiresActiveItem (id) costs (feeBid) {
        Item storage item = items[id];
        SaleKindInterface.Bid storage topBid = topBids[id];

        /* Calculated required bid price. */
        uint requiredBidPrice = SaleKindInterface.requiredBidPrice(item.saleKind, item.basePrice, item.extra, item.expirationTime, topBid);
        /* Assert bid amount is sufficient. */
        require(amount >= requiredBidPrice);
        if (topBid.bidder != address(0)) {
            /* Return locked tokens to the previous high bidder. */
            require(item.paymentToken.transfer(topBid.bidder, topBid.amount));
        }
        /* Lock tokens for the new high bidder. */
        require(item.paymentToken.transferFrom(msg.sender, this, amount));
        /* Store the new high bid. */
        topBids[id] = SaleKindInterface.Bid(msg.sender, amount, now);
        /* Log the bid event. */
        ItemBidOn(id, msg.sender, amount, now);
    }

    /* Called by a buyer to purchase an item or finalize an auction they have won. Frontend address provided by the frontend. */
    function purchaseItem (bytes32 id, address frontend) public requiresActiveItem (id) costs (feeBuy) {
      
        Item storage item = items[id];
        SaleKindInterface.Bid storage topBid = topBids[id];

        /* Ensure that the item can be purchased. */
        require(SaleKindInterface.canPurchaseItem(item.saleKind, item.expirationTime, topBid));

        /* Release tokens from bid escrow. */
        if (topBid.bidder != address(0)) {
            item.paymentToken.transfer(msg.sender, topBid.amount);
        }

        /* Calculate the final price and transfer the tokens from the buyer. */
        uint price = SaleKindInterface.calculateFinalPrice(item.saleKind, item.basePrice, item.extra, item.listingTime, item.expirationTime, topBid);
        require(item.paymentToken.transferFrom(msg.sender, this, price));

        /* Calculate and credit the owner fee. */
        uint feeToOwner = price * (feeOwner / 10000);
        collectedFees[owner][item.paymentToken] += feeToOwner;
      
        /* Calculate and credit the public benefit fee. */
        uint feeToPublicBenefit = price * (feePublicBenefit / 10000);
        collectedFees[publicBeneficiary][item.paymentToken] += feeToPublicBenefit;

        /* Calculate and credit the frontend fee. */
        uint feeToFrontend = price * (feeFrontend / 10000);
        collectedFees[frontend][item.paymentToken] += feeToFrontend;

        /* Calculate final price (what the seller will receive). */
        uint finalPrice = price - feeToOwner - feeToPublicBenefit - feeToFrontend;
  
        /* Send funds to the escrow provider. */
        require(item.escrowProvider.holdInEscrow(id, msg.sender, item.seller, item.paymentToken, finalPrice));

        /* Transfer ownership of the asset. */
        NonFungibleAssetInterface.transferOwnership(item.assetKind, item.contractAddress, msg.sender, item.assetExtra);

        /* Record the sale. */
        sales[id] = Sale(msg.sender, price, now, new bytes(0));

        /* Log the purchase event. */
        ItemPurchased(id, msg.sender, price);
    }

    /* Called by the seller of an item to finalize sale to the buyer, linking the IPFS metadata. */
    function finalizeSale (bytes32 id, bytes saleMetadataHash) public {
        require(items[id].seller == msg.sender);
        sales[id].metadataHash = saleMetadataHash;
        SaleFinalized(id, saleMetadataHash);
    }

}
