/*

  Decentralized digital item exchange. Supports any digital asset that can be represented on the Ethereum blockchain.

  Let us suppose two agents interacting with a distributed ledger have utility functions preferencing certain states of that ledger over others.
  Aiming to maximize their utility, these agents may construct with their utility functions along with the present ledger state a mapping of state transitions (transactions) to marginal utilities.
  Any composite state transition with positive marginal utility for and enactable by the combined permissions of both agents thus is a mutually desirable trade, and the trustless 
  code execution provided by a distributed ledger renders the requisite atomicity trivial.

  Relative to this model, the present Exchange instantiation makes two concessions to practicality:
  - State transition preferences are not matched directly but instead intermediated by a standard of tokenized value.
  - A small fee is charged in WYV for order settlement, with an amount configurable by the frontend hosting the orderbook.

  Solidity presently possesses neither a strong functional typesystem nor runtime reflection (ABI encoding in Solidity), so we must be a bit clever in implementation.

  TODO: Clarify maker/taker distinction, require fee agreement, see if we can implement negative fees. Consider implementing frontend order signatures.
  TODO: Need outside view function to check if order can be settled (orderbook scan).
  
*/

pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";

import "../registry/ProxyRegistry.sol";
import "../registry/AuthenticatedLazyBank.sol";
import "../common/ArrayUtils.sol";
import "../common/ReentrancyGuarded.sol";
import "./SaleKindInterface.sol";

/**
 * @title ExchangeCore
 * @author Project Wyvern Developers
 */
contract ExchangeCore is ReentrancyGuarded {

    /* The token used to pay exchange fees. */
    ERC20 public exchangeTokenAddress;

    /* User registry. */
    ProxyRegistry public registry;

    /* Lazy bank. */
    AuthenticatedLazyBank public bank;

    /* Top bids for all bid-supporting auctions, by hash. */
    mapping(bytes32 => SaleKindInterface.Bid) public topBids;
 
    /* Cancelled / finalized orders, by hash. */
    mapping(bytes32 => bool) public cancelledOrFinalized;

    /* Orders verified by on-chain approval (alternative to ECDSA signatures so that smart contracts can place orders directly). */
    mapping(bytes32 => bool) public approvedOrders;

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
        /* Exchange address, intended as a versioning mechanism. */
        address exchange;
        /* Order maker address. */
        address maker;
        /* Order taker address, if specified. */
        address taker;
        /* Maker fee of the order (in Exchange fee tokens). */
        uint makerFee;
        /* Taker fee of the order (in Exchange fee tokens). */
        uint takerFee;
        /* Order fee recipient. */
        address feeRecipient;
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
        /* replacementPattern pattern. */
        bytes replacementPattern;
        /* Order metadata IPFS hash. */
        bytes metadataHash;
        /* Token used to pay for the order. */
        ERC20 paymentToken;
        /* Base price of the order (in paymentTokens). */
        uint basePrice;
        /* Auction extra parameter - minimum bid increment for English auctions, decay factor for Dutch auctions. */
        uint extra;
        /* Listing timestamp. */
        uint listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint expirationTime;
        /* Order salt, used to prevent duplicate hashes. */
        uint salt;
    }
    
    event OrderApproved   (bytes32 hash, address indexed approver, Order order, bool orderbookInclusionDesired);
    event OrderCancelled  (bytes32 hash);
    event OrderBidOn      (bytes32 hash, address indexed bidder, uint amount, uint timestamp);
    event OrdersMatched   (Order buy, Order sell);

    function chargeFee(address from, address to, uint amount)
        internal
    {
        if (amount > 0) {
            bank._transferTo(from, to, exchangeTokenAddress, amount);
        }
    }

    function hashOrderPartOne(Order order)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(order.exchange, order.maker, order.taker, order.makerFee, order.takerFee, order.feeRecipient, order.side, order.saleKind, order.target, order.howToCall, order.calldata, order.replacementPattern);
    }

    function hashOrderPartTwo(Order order)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(order.metadataHash, order.paymentToken, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt);
    }

    function hashOrder(Order order)
        internal
        pure
        returns (bytes32)
    {
        /* This is silly, but necessary due to Solidity compiler stack size constraints. FIXME, waste of gas. */
        return keccak256(hashOrderPartOne(order), hashOrderPartTwo(order));
    }

    function hashToSign(Order order)
        internal
        pure
        returns (bytes32)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 hash = keccak256(prefix, hashOrder(order));
        return hash;
    }

    function requireValidOrder(Order order, Sig sig)
        internal
        view
        returns (bytes32)
    {
        bytes32 hash = hashToSign(order);
        require(validateOrder(hash, order, sig));
        return hash;
    }

    function validateOrder(bytes32 hash, Order memory order, Sig memory sig) 
        view
        internal
        returns (bool)
    {
        return(
            /* Order must be targeted at this protocol version (this Exchange contract). */
            order.exchange == address(this) &&
            /* Order must have not been canceled or already filled. */
            !cancelledOrFinalized[hash] && 
            /* Order authentication. Order must be either (a) sent by maker, (b) previously approved, or (c) ECDSA-signed by maker. */
            (msg.sender == order.maker || approvedOrders[hash] || ecrecover(hash, sig.v, sig.r, sig.s) == order.maker) &&
            /* Order must possess valid sale kind parameter combination. */
            SaleKindInterface.validateParameters(order.side, order.saleKind, order.expirationTime)
        );
    }

    function approveOrder(Order memory order, bool orderbookInclusionDesired)
        internal
    {
        require(msg.sender == order.maker);
        bytes32 hash = hashToSign(order);
        require(!approvedOrders[hash]);
        approvedOrders[hash] = true;
        OrderApproved(hash, msg.sender, order, orderbookInclusionDesired);
    }

    function cancelOrder(Order memory order, Sig memory sig) 
        internal
    {
        /* CHECKS */
        bytes32 hash = requireValidOrder(order, sig);
        require(msg.sender == order.maker);
  
        /* EFFECTS */
        cancelledOrFinalized[hash] = true;

        OrderCancelled(hash);
    }

    function bid (Order order, Sig sig, uint amount)
        internal
        reentrancyGuard
    {
        /* CHECKS */
  
        bytes32 hash = requireValidOrder(order, sig);

        SaleKindInterface.Bid storage topBid = topBids[hash];
        
        /* Calculated required bid price. */
        uint requiredBidPrice = SaleKindInterface.requiredBidPrice(order.side, order.saleKind, order.basePrice, order.extra, order.expirationTime, topBid);

        /* Assert bid amount is sufficient. */
        require(amount >= requiredBidPrice);

        /* EFFECTS */

        /* Store the new high bid. */
        topBids[hash] = SaleKindInterface.Bid(msg.sender, amount);

        /* Unlock tokens to the previous high bidder, if existent. */
        if (topBid.bidder != address(0)) {
            bank._unlock(topBid.bidder, order.paymentToken, topBid.amount);
        }

        /* Lock tokens for the new high bidder. */
        bank._lazyLock(msg.sender, order.paymentToken, amount);

        /* Log the bid event. */
        OrderBidOn(hash, msg.sender, amount, now);
    }

    function calculateMatchPrice(Order buy, Order sell, SaleKindInterface.Bid storage topBid)
        view
        internal
        returns (uint price)
    {
        /* Calculate sell price. */
        uint sellPrice = SaleKindInterface.calculateFinalPrice(sell.side, sell.saleKind, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, topBid);

        /* Calculate buy price. */
        uint buyPrice = SaleKindInterface.calculateFinalPrice(buy.side, buy.saleKind, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, topBid);

        /* Require price cross. */
        require(buyPrice >= sellPrice);
        
        /* Time priority. */
        price = sell.listingTime < buy.listingTime ? sellPrice : buyPrice;

        return price;
    }

    function executeFundsTransfer(Order buy, Order sell, SaleKindInterface.Bid storage topBid)
        internal
    {
        /* Calculate match price. */
        uint price = calculateMatchPrice(buy, sell, topBid);

        /* TODO: Charge fees. */
        chargeFee(buy.maker, buy.feeRecipient, buy.makerFee);
        chargeFee(sell.maker, sell.feeRecipient, sell.makerFee);

        /* Unlock tokens for top bidder, if existent. */
        if (topBid.bidder != address(0)) {
            bank._unlock(topBid.bidder, sell.paymentToken, topBid.amount);
        }

        /* Debit buyer. */
        bank._lazyDebit(buy.maker, sell.paymentToken, price);

        /* Credit seller. */
        bank._credit(sell.maker, sell.paymentToken, price);
    }

    function ordersCanMatch(Order buy, Order sell, SaleKindInterface.Bid storage topBid)
        internal
        view
        returns (bool)
    {
        return (
            /* Must be opposite-side. */
            (buy.side == SaleKindInterface.Side.Buy && sell.side == SaleKindInterface.Side.Sell) &&     
            /* Must use same payment token. */
            (buy.paymentToken == sell.paymentToken) &&
            /* Must match maker/taker. */
            (sell.taker == address(0) || sell.taker == buy.maker) &&
            (buy.taker == address(0) || buy.taker == sell.maker) &&
            /* Must match target. */
            (buy.target == sell.target) &&
            /* Must match howToCall. */
            (buy.howToCall == sell.howToCall) &&
            /* Buy-side order must be settleable. */
            SaleKindInterface.canSettleOrder(buy.saleKind, sell.maker, buy.expirationTime, SaleKindInterface.Bid({ bidder: address(0), amount: 0 })) &&
            /* Sell-side order must be settleable. */
            SaleKindInterface.canSettleOrder(sell.saleKind, buy.maker, sell.expirationTime, topBid)
        );
    }

    function atomicMatch(Order buy, Sig buySig, Order sell, Sig sellSig)
        internal
        reentrancyGuard
    {
        /* CHECKS */
      
        bytes32 buyHash = requireValidOrder(buy, buySig);
        bytes32 sellHash = requireValidOrder(sell, sellSig); 
        
        /* Fetch top bid, if existent. */
        SaleKindInterface.Bid storage topBid = topBids[sellHash];

        /* Must be matchable. */
        require(ordersCanMatch(buy, sell, topBid));
      
        /* Must match calldata after replacementPattern. */ 
        ArrayUtils.guardedArrayReplace(buy.calldata, sell.calldata, buy.replacementPattern);
        ArrayUtils.guardedArrayReplace(sell.calldata, buy.calldata, sell.replacementPattern);
        require(ArrayUtils.arrayEq(buy.calldata, sell.calldata));

        /* Retrieve proxy (the registry contract is trusted). */
        AuthenticatedProxy proxy = registry.proxies(sell.maker);

        /* Proxy must exist. */
        require(proxy != address(0));

        /* EFFECTS */

        /* Mark orders as finalized. */
        cancelledOrFinalized[buyHash] = true;
        cancelledOrFinalized[sellHash] = true;

        /* Validate balances and transfer funds. */ 
        executeFundsTransfer(buy, sell, topBid);

        /* INTERACTIONS */

        /* Execute call through proxy. */
        require(proxy.proxy(sell.target, sell.howToCall, sell.calldata));

        /* Log match event. */
        OrdersMatched(buy, sell);
    }

}
