/*

  Decentralized digital item exchange.

  Let us suppose two agents interacting with a distributed ledger have utility functions preferencing certain states of that ledger over others.
  Aiming to maximize their utility, these agents may construct with their utility functions along with the present ledger state a mapping of state transitions (transactions) to marginal utilities.
  Any composite state transition with positive marginal utility for and enactable by the combined permissions of both agents thus is a mutually desirable trade, and the trustless 
  code execution provided by a distributed ledger renders the requisite atomicity trivial.

  Relative to this model, the present Exchange instantiation makes two concessions to practicality:
  - State transition preferences are not matched directly but instead intermediated by a standard of tokenized value.
  - A small fee is charged in the token of payment, split equally between protocol development, frontend compensation, and a chosen public beneficiary.

  Solidity presently possesses neither a strong functional typesystem nor runtime reflection, so we must be a bit clever in implementation.

  Buy intent    :: State transition, from address unspecified
  Sell intent   :: State transition -> bool (must be true), from address specified

  TODO: 
  - Checks - effects - interactions
  - Clarify sale kind interface, other auction types
   
  (offchain => think about spam prevention, maybe intermediaries keep orderbooks, this *also* solves frontend fee enforcement since intermediary can enforce)

  *Build complete testnet prototype and user test before audit / mainnet deployment.*

*/

pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

import "../registry/Registry.sol";
import "../escrow/EscrowProvider.sol";
import "./SaleKindInterface.sol";

/**
 * @title Exchange
 * @author Project Wyvern Developers
 */
contract Exchange is Ownable, Pausable {

    /* The owner address of the exchange (a) can withdraw fees periodically and (b) can change the fee amounts, escrow settings, and whitelists. */

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
    mapping(address => mapping(address => uint)) public collectedFees;

    // TODO Genericize this for middle transfer layer, withdraw pattern.

    /* The token used to pay exchange fees. */
    ERC20 public exchangeTokenAddress;

    /* All items that have ever been listed. */
    Item[] public items;

    /* Number of items ever listed. */
    uint public numberOfItems = 0;

    /* All sales that have ever occurred. */
    mapping(uint => Sale) public sales;

    /* Top bids for all bid-supporting auctions. */
    mapping(uint => SaleKindInterface.Bid) public topBids;

    /* ERC20 whitelist. */
    mapping(address => bool) public erc20Whitelist;

    /* Escrow provider whitelist. */
    mapping(address => bool) public escrowProviderWhitelist;

    /* User registry. */
    Registry public registry;

    /* Side enum. */
    enum Side { Buy, Sell }

    /* An item listed for sale on the exchange. */
    struct Item {
        /* The address buying/selling the item. */
        address initiator;
        /* Side of sell. */
        Side side;
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
        /* Target, for buy-side orders. */
        address target;
        /* Calldata, for buy-side orders. */
        bytes calldata;
        /* The escrow provider contract, which is paid a fee to arbitrage escrow disputes and must provide specific functions. 0 for no escrow. */
        EscrowProvider escrowProvider;
        /* Whether or not the listing has been removed. */
        bool removed;

        /* Note: most of this (all except metadata hash, initiator, and removed?) could be stored on IPFS and validated with ecrecover on-demand. Not sure if the gas costs would be cheaper for the average use case or not. */
    }

    struct Sale {
        /* Address of the buyer. */
        address buyer;
        /* Sale metadata IPFS hash. */
        bytes metadataHash;
    }

    event ItemListed    (uint id, address indexed initiator, Side side, bytes metadataHash, SaleKindInterface.SaleKind saleKind, ERC20 paymentToken, uint price, uint timestamp, uint expirationTime, uint extra, address indexed target, bytes calldata, EscrowProvider escrowProvider);
    event ItemRemoved   (uint id);
    event ItemBidOn     (uint id, address indexed bidder, uint amount, uint timestamp);
    event ItemFinalized (uint id, address indexed finalizer, uint price);
    event SaleFinalized (uint id, bytes metadataHash);
    event PublicBeneficiaryChanged (address indexed newAddress);

    modifier requiresActiveItem (uint id) {
        require((items[id].initiator != address(0)) && (!items[id].removed) && (sales[id].buyer == address(0)));
        _;
    }

    modifier costs (uint amount) {
        if (amount > 0) {
            require(exchangeTokenAddress.transferFrom(msg.sender, this, amount));
            collectedFees[owner][exchangeTokenAddress] += amount;
        }
        _;
    }

    function setPublicBeneficiary(address newAddress)
        public
        onlyOwner
    {
        publicBeneficiary = newAddress;
        PublicBeneficiaryChanged(newAddress);
    }

    function modifyERC20Whitelist(address token, bool value)
        public
        onlyOwner
    {
        erc20Whitelist[token] = value;
    }

    function modifyEscrowProviderWhitelist(address provider, bool value)
        public
        onlyOwner
    {
        escrowProviderWhitelist[provider] = value;
    }

    function withdrawFees(address dest, address token)
        public
        whenNotPaused
    {
        uint amount = collectedFees[msg.sender][token];
        collectedFees[msg.sender][token] = 0;
        require(ERC20(token).transfer(dest, amount));
    }

    function setFees(uint listFee, uint bidFee, uint buyFee, uint ownerFee, uint publicBenefitFee, uint frontendFee)
        public
        onlyOwner
    {
        feeList = listFee;
        feeBid = bidFee;
        feeBuy = buyFee;
        feeOwner = ownerFee;
        feePublicBenefit = publicBenefitFee;
        feeFrontend = frontendFee;
    }

    function listItem(Side side, bytes metadataHash, SaleKindInterface.SaleKind saleKind, ERC20 paymentToken, uint price, uint expirationTime, uint extra, address target, bytes calldata, EscrowProvider escrowProvider)
        public
        whenNotPaused
        costs (feeList)
        returns (uint id)
    {

        /* Escrow provider must be whitelisted. */
        require((escrowProvider == address(0)) || escrowProviderWhitelist[escrowProvider]);

        /* Payment token must be whitelisted. */
        require(erc20Whitelist[paymentToken]);

        /* Buy-side listings cannot be English auctions. */
        require(saleKind != SaleKindInterface.SaleKind.EnglishAuction || side == Side.Sell);

        /* Parameters must validate. */
        require(SaleKindInterface.validateParameters(saleKind, expirationTime));
        
        /* Expiration time must be zero or past now. */
        require(expirationTime == 0 || expirationTime > now);

        return writeItem(side, metadataHash, saleKind, paymentToken, price, expirationTime, extra, target, calldata, escrowProvider);

    }

    /**
  
      Separated due to Solidity compiler constraints.
          
     */
    function writeItem(Side side, bytes metadataHash, SaleKindInterface.SaleKind saleKind, ERC20 paymentToken, uint price, uint expirationTime, uint extra, address target, bytes calldata, EscrowProvider escrowProvider)
        internal
        returns (uint id)
    {

        id = numberOfItems;
        numberOfItems += 1;
        items.push(Item(msg.sender, side, metadataHash, saleKind, paymentToken, price, now, expirationTime, extra, target, calldata, escrowProvider, false));
        ItemListed(id, msg.sender, side, metadataHash, saleKind, paymentToken, price, now, expirationTime, extra, target, calldata, escrowProvider);
        return id;
  
    }

    function removeItem (uint id)
        public
        requiresActiveItem(id)
    {
        Item storage item = items[id];
        require(item.initiator == msg.sender);
        item.removed = true;
        ItemRemoved(id);
    }

    function bidOnItem (uint id, uint amount)
        public
        whenNotPaused
        requiresActiveItem (id)
        costs (feeBid)
    {
        Item storage item = items[id];
        SaleKindInterface.Bid storage topBid = topBids[id];
        
        /* Calculated required bid price. */
        uint requiredBidPrice = SaleKindInterface.requiredBidPrice(item.saleKind, item.basePrice, item.extra, item.expirationTime, topBid);

        /* Assert bid amount is sufficient. */
        require(amount >= requiredBidPrice);

        /* Store the new high bid. */
        topBids[id] = SaleKindInterface.Bid(msg.sender, amount);

        /* Log the bid event. */
        ItemBidOn(id, msg.sender, amount, now);

        /* Return locked tokens to the previous high bidder, if existent. */
        if (topBid.bidder != address(0)) {
            // TODO Swap me to withdraw pattern?
            // could also allow to fail (tokens locked in that case)
            require(item.paymentToken.transfer(topBid.bidder, topBid.amount));
        }

        /* Lock tokens for the new high bidder. */
        require(item.paymentToken.transferFrom(msg.sender, this, amount));
 
    }

    function validateTradeAndExecuteFundsTransfer (uint id, Item item, SaleKindInterface.Bid topBid, address frontend)
        internal
    {
        /* Ensure that the item can be purchased. */
        require(SaleKindInterface.canPurchaseItem(item.saleKind, item.expirationTime, topBid));

        /* Ensure that the proxy exists. */
        require(registry.proxies(item.side == Side.Buy ? msg.sender : item.initiator) != address(0));

        /* Calculate the purchase price and transfer the tokens from the buyer. */
        uint price = SaleKindInterface.calculateFinalPrice(item.saleKind, item.basePrice, item.extra, item.listingTime, item.expirationTime, topBid);

        /* Select payer/payee. */
        address payer = item.side == Side.Buy ? item.initiator : msg.sender;
        address payee = item.side == Side.Buy ? msg.sender : item.initiator;

        /* Calculate and credit the owner fee. */
        uint feeToOwner = price * feeOwner / 10000;
        collectedFees[owner][item.paymentToken] += feeToOwner;
      
        /* Calculate and credit the public benefit fee. */
        uint feeToPublicBenefit = price * feePublicBenefit / 10000;
        collectedFees[publicBeneficiary][item.paymentToken] += feeToPublicBenefit;

        /* Calculate and credit the frontend fee. */
        uint feeToFrontend = price * feeFrontend / 10000;
        collectedFees[frontend][item.paymentToken] += feeToFrontend;

        /* Calculate final price (what the seller will receive). */
        uint finalPrice = price - feeToOwner - feeToPublicBenefit - feeToFrontend;

        /* Log the purchase event. */
        ItemFinalized(id, msg.sender, price);

        /* Record the sale. */
        sales[id] = Sale(msg.sender, new bytes(0));

        /* Withdraw tokens from payer, unless tokens were already sent with the high bid. */
        if (topBid.bidder == address(0)) {
            require(item.paymentToken.transferFrom(payer, this, price));
        }

        /* Send funds to the escrow provider, if one is being used. Else send funds directly to seller. */
        if (item.escrowProvider != address(0)) {
            item.paymentToken.approve(item.escrowProvider, finalPrice);
            require(item.escrowProvider.holdInEscrow(id, payer, payee, item.paymentToken, finalPrice));
        } else {
            require(item.paymentToken.transfer(payee, finalPrice));
        }
        
    }

    function proxyCall(AuthenticatedProxy proxy, uint id, address target, bytes calldata, bytes replace, uint start, uint length, uint8 v, bytes32 r, bytes32 s)
        internal
    {
        /* Execute the function. */
        require(proxy.proxy(id, target, calldata, replace, start, length, v, r, s));
    }

    /* Called by a buyer to purchase an item or finalize an auction they have won. Frontend address provided by the frontend. */
    function purchaseItem (uint id, address frontend, bytes calldata, bytes replace, uint start, uint length, uint8 v, bytes32 r, bytes32 s)
        public
        whenNotPaused
        requiresActiveItem(id)
        costs (feeBuy)
    {
      
        Item storage item = items[id];
        SaleKindInterface.Bid storage topBid = topBids[id];

        /* Execute funds transfer. */
        validateTradeAndExecuteFundsTransfer(id, item, topBid, frontend);

        /* Proxy the call. */
        proxyCall(
            /* Source proxy: buyer for buy-side, seller for sell-side. */
            registry.proxies(item.side == Side.Buy ? msg.sender : item.initiator),
            /* Item ID, used to prevent replay attacks. */
            id,
            /* Item-specified target. */
            item.target,
            /* Calldata: item calldata for buy-side, specified calldata for sell-side. */
            item.side == Side.Buy ? item.calldata : calldata,
            /* Remaining parameters. */
            replace, start, length, v, r, s);

    }

    /* Called by the seller of an item to finalize sale to the buyer, linking the IPFS metadata. */
    function finalizeSale (uint id, bytes saleMetadataHash)  
        public
    {
        require(items[id].initiator == msg.sender);
        sales[id].metadataHash = saleMetadataHash;
        SaleFinalized(id, saleMetadataHash);
    }

}
