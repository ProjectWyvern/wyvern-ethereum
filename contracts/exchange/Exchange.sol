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

  TODO: 
  - Checks - effects - interactions
   
  *Build complete testnet prototype and user test before audit / mainnet deployment.*

*/

pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/token/ERC20.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

import "../registry/Registry.sol";
import "../common/CachedBank.sol";
import "./SaleKindInterface.sol";

/**
 * @title Exchange
 * @author Project Wyvern Developers
 */
contract Exchange is Ownable, Pausable, CachedBank {

    /* The owner address of the exchange (a) receives fees (specified by feeOwner) and (b) can change the fee amounts and token whitelist. */

    /* Public benefit address. */
    address public publicBeneficiary; 

    /* The fee required to bid on an item. */
    uint public feeBid;

    /* Transaction percentage fee paid to contract owner, in basis points. */
    uint public feeOwner;

    /* Transaction percentage fee paid to public beneficiary, in basis points. */
    uint public feePublicBenefit;

    /* Transaction percentage fee paid to buy-side frontend, in basis points. */
    uint public feeBuyFrontend;
    
    /* Transaction percentage fee paid to sell-side frontend, in basis points. */
    uint public feeSellFrontend;

    /* The token used to pay exchange fees. */
    ERC20 public exchangeTokenAddress;

    /* User registry. */
    Registry public registry;

    /* ERC20 whitelist. */
    mapping(address => bool) public erc20Whitelist;

    /* Top bids for all bid-supporting auctions, by hash. */
    mapping(bytes32 => SaleKindInterface.Bid) public topBids;
 
    /* Cancelled / finalized orders, by hash. */
    mapping(bytes32 => bool) cancelledOrFinalized;
   
    /* An ECDSA signature. */ 
    struct Sig {
        /* v parameter */
        uint8 v;
        /* r parameter */
        bytes32 r;
        /* s parameter */
        bytes32 s;
    }

    /* An order on the exchange. */
    struct Order {
        /* The address buying/selling the item. */
        address initiator;
        /* Side (buy/sell). */
        SaleKindInterface.Side side;
        /* Kind of sale. */
        SaleKindInterface.SaleKind saleKind;
        /* Target. */
        address target;
        /* HowToCall. */
        AuthenticatedProxy.HowToCall howToCall;
        /* Calldata. */
        bytes calldata;
        /* Replace start index. */
        uint start;
        /* Replace length. */
        uint length;
        /* Order metadata IPFS hash. */
        bytes metadataHash;
        /* Token used to pay for the item. */
        ERC20 paymentToken;
        /* Base price of the item (tokens). */
        uint basePrice;
        /* Auction extra parameter - minimum bid increment for English auctions, decay factor for Dutch auctions. */
        uint extra;
        /* Listing timestamp. */
        uint listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint expirationTime;
        /* Order frontend. Fees split between buy / sell. */
        address frontend;
    }

    event PublicBeneficiaryChanged (address indexed newAddress);
    event ERC20WhitelistChanged    (address indexed token, bool value);
    event FeesChanged              (uint feeBid, uint feeOwner, uint feePublicBenefit, uint feeBuyFrontend, uint feeSellFrontend);

    event OrderCancelled  (bytes32 hash);
    event OrderBidOn      (bytes32 hash, address indexed bidder, uint amount, uint timestamp);
    event OrdersMatched   (Order buy, Order sell);

    modifier costs (uint amount) {
        if (amount > 0) {
            debit(msg.sender, exchangeTokenAddress, amount);
            credit(owner, exchangeTokenAddress, amount);
        }
        _;
    }

    modifier withValidOrder(Order order, Sig sig) {
        bytes32 hash = keccak256(order);
        require(!cancelledOrFinalized[hash]);
        require(ecrecover(hash, sig.v, sig.r, sig.s) == order.initiator);
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
        ERC20WhitelistChanged(token, value);
    }

    function setFees(uint bidFee, uint ownerFee, uint publicBenefitFee, uint frontendBuyFee, uint frontendSellFee)
        public
        onlyOwner
    {
        feeBid = bidFee;
        feeOwner = ownerFee;
        feePublicBenefit = publicBenefitFee;
        feeBuyFrontend = frontendBuyFee;
        feeSellFrontend = frontendSellFee;
        FeesChanged(feeBid, feeOwner, feePublicBenefit, feeBuyFrontend, feeSellFrontend);
    }

    function cancelOrder(Order order, Sig sig) 
        internal
        withValidOrder(order, sig) 
    {
        require(msg.sender == order.initiator);
        bytes32 hash = keccak256(order);
        cancelledOrFinalized[hash] = true;
        OrderCancelled(hash);
    }

    function bid (Order order, Sig sig, uint amount)
        internal
        costs (feeBid)
        withValidOrder(order, sig) 
    {
        bytes32 hash = keccak256(order);

        SaleKindInterface.Bid storage topBid = topBids[hash];
        
        /* Calculated required bid price. */
        uint requiredBidPrice = SaleKindInterface.requiredBidPrice(order.side, order.saleKind, order.basePrice, order.extra, order.expirationTime, topBid);

        /* Assert bid amount is sufficient. */
        require(amount >= requiredBidPrice);

        /* Store the new high bid. */
        topBids[hash] = SaleKindInterface.Bid(msg.sender, amount);

        /* Log the bid event. */
        OrderBidOn(hash, msg.sender, amount, now);

        /* Unlock tokens to the previous high bidder, if existent. */
        if (topBid.bidder != address(0)) {
            unlock(topBid.bidder, order.paymentToken, topBid.amount);
        }

        /* Lock tokens for the new high bidder. */
        lock(msg.sender, order.paymentToken, amount);
    }

    function executeFundsTransfer(Order buy, Order sell)
        internal
    {
        /* Fetch top bid, if existent. */
        SaleKindInterface.Bid storage topBid = topBids[keccak256(sell)];

        /* Calculate sell price. */
        uint sellPrice = SaleKindInterface.calculateFinalPrice(sell.side, sell.saleKind, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, topBid);

        /* Calculate buy price. */
        uint buyPrice = SaleKindInterface.calculateFinalPrice(buy.side, buy.saleKind, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, topBid);

        /* Require price cross. */
        require(buyPrice >= sellPrice);
        
        /* Time priority. */
        uint price = sell.listingTime < buy.listingTime ? sellPrice : buyPrice;

        /* Calculate and credit owner fee. */
        uint feeToOwner = price * feeOwner / 10000;
        credit(owner, sell.paymentToken, feeToOwner);

        /* Calculate and credit public benefit fee. */
        uint feeToPublicBenefit = price * feePublicBenefit / 10000;
        credit(publicBeneficiary, sell.paymentToken, feeToPublicBenefit);

        /* Calculate and credit sell frontend fee. */
        uint feeToSellFrontend = price * feeSellFrontend / 10000;
        credit(sell.frontend, sell.paymentToken, feeToSellFrontend);

        /* Calculate and credit buy frontend fee. */
        uint feeToBuyFrontend = price * feeBuyFrontend / 10000;
        credit(buy.frontend, buy.paymentToken, feeToBuyFrontend);

        /* Calculate final price. */
        uint finalPrice = price - feeToOwner - feeToPublicBenefit - feeToSellFrontend - feeToBuyFrontend;

        /* Unlock tokens for top bidder, if existent. */
        if (topBid.bidder != address(0)) {
            unlock(topBid.bidder, sell.paymentToken, topBid.amount);
        }

        /* Debit buyer. */
        debit(buy.initiator, sell.paymentToken, price);

        /* Credit seller. */
        credit(sell.initiator, sell.paymentToken, finalPrice);
    }

    function atomicMatch(Order buy, Sig buySig, Order sell, Sig sellSig)
        internal
        withValidOrder(buy, buySig)
        withValidOrder(sell, sellSig)
    {
        /* Must be opposite-side. */
        require(buy.side == SaleKindInterface.Side.Buy && sell.side == SaleKindInterface.Side.Sell);

        /* Must use same payment token. */
        require(buy.paymentToken == sell.paymentToken);

        /* Payment token must be whitelisted (or should frontends do this?). */
        require(erc20Whitelist[buy.paymentToken]);

        /* Must be settleable. */
        SaleKindInterface.Bid storage topBid = topBids[keccak256(sell)];
        require(SaleKindInterface.canSettleOrder(buy.side, buy.saleKind, sell.initiator, buy.expirationTime, SaleKindInterface.Bid({ bidder: address(0), amount: 0 })));
        require(SaleKindInterface.canSettleOrder(sell.side, sell.saleKind, buy.initiator, sell.expirationTime, topBid));
        
        /* Must match target. */
        require(buy.target == sell.target);

        /* Must match howToCall. */
        require(buy.howToCall == sell.howToCall);
       
        /* Must match calldata. */ 
        require(buy.calldata.length == sell.calldata.length);

        if (buy.length > 0) {
            ArrayUtils.arrayCopy(buy.calldata, ArrayUtils.toBytes(sell.initiator), buy.start, buy.length);
        }
        if (sell.length > 0) {
            ArrayUtils.arrayCopy(sell.calldata, ArrayUtils.toBytes(buy.initiator), sell.start, sell.length);
        }
        
        require(ArrayUtils.arrayEq(buy.calldata, sell.calldata));

        AuthenticatedProxy proxy = registry.proxies(sell.initiator);

        /* Proxy must exist. */
        require(proxy != address(0));

        /* Validate and transfer funds. */ 
        executeFundsTransfer(buy, sell);

        /* Execute call through proxy. */
        require(proxy.proxy(sell.target, sell.howToCall, sell.calldata));

        OrdersMatched(buy, sell);

        return;
    }

}
