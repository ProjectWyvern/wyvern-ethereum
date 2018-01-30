/*

  Decentralized digital asset exchange. Supports any digital asset that can be represented on the Ethereum blockchain (transferred in an Ethereum transaction).

  Let us suppose two agents interacting with a distributed ledger have utility functions preferencing certain states of that ledger over others.
  Aiming to maximize their utility, these agents may construct with their utility functions along with the present ledger state a mapping of state transitions (transactions) to marginal utilities.
  Any composite state transition with positive marginal utility for and enactable by the combined permissions of both agents thus is a mutually desirable trade, and the trustless 
  code execution provided by a distributed ledger renders the requisite atomicity trivial.

  Relative to this model, this instantiation makes two concessions to practicality:
  - State transition preferences are not matched directly but instead intermediated by a standard of tokenized value.
  - A small fee can be charged in WYV for order settlement in an amount configurable by the frontend hosting the orderbook.

  Solidity presently possesses neither a first-class functional typesystem nor runtime reflection (ABI encoding in Solidity), so we must be a bit clever in implementation and work at a lower level than would be ideal.
 
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
        /* Maker fee of the order (in Exchange fee tokens), unused for taker order. */
        uint makerFee;
        /* Taker fee of the order (in Exchange fee tokens), or maximum taker fee for a taker order. */
        uint takerFee;
        /* Order fee recipient or zero address for taker order. */
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
        /* Calldata replacement pattern. */
        bytes replacementPattern;
        /* Static call target, zero-address for no static call. */
        address staticTarget;
        /* Static call extra data. */
        bytes staticExtradata;
        /* Token used to pay for the order. */
        ERC20 paymentToken;
        /* Base price of the order (in paymentTokens). */
        uint basePrice;
        /* Auction extra parameter - minimum bid increment for English auctions, starting/ending price difference. */
        uint extra;
        /* Listing timestamp. */
        uint listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint expirationTime;
        /* Order salt, used to prevent duplicate hashes. */
        uint salt;
    }
    
    event OrderApprovedPartOne    (bytes32 indexed hash, address exchange, address indexed maker, address taker, uint makerFee, uint takerFee, address indexed feeRecipient, SaleKindInterface.Side side, SaleKindInterface.SaleKind saleKind, address target, AuthenticatedProxy.HowToCall howToCall, bytes calldata);
    event OrderApprovedPartTwo    (bytes32 indexed hash, bytes replacementPattern, address staticTarget, bytes staticExtradata, ERC20 paymentToken, uint basePrice, uint extra, uint listingTime, uint expirationTime, uint salt, bool orderbookInclusionDesired);
    event OrderCancelled          (bytes32 indexed hash);
    event OrderBidOn              (bytes32 indexed hash, address indexed bidder, uint amount);
    event OrdersMatched           (bytes32 indexed buyHash, bytes32 indexed sellHash);

    function chargeFee(address from, address to, uint amount)
        internal
    {
        if (amount > 0) {
            bank._transferTo(from, to, exchangeTokenAddress, amount);
        }
    }

    function staticCall(address target, bytes calldata, bytes extradata)
        internal
        view
        returns (bool result)
    {
        bytes memory combined = new bytes(calldata.length + extradata.length);
        uint len = combined.length;
        for (uint i = 0; i < calldata.length; i++) {
            combined[i] = calldata[i];
        }
        for (uint j = 0; j < extradata.length; j++) {
            combined[j + calldata.length] = extradata[j];
        }
        assembly {
            result := staticcall(gas, target, combined, len, combined, 0)
        }
        return result;
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
        return keccak256(order.staticTarget, order.staticExtradata, order.paymentToken, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt);
    }

    function hashOrder(Order order)
        internal
        pure
        returns (bytes32)
    {
        /* This is silly, but necessary due to Solidity compiler stack size constraints. Should be fixed, waste of gas. */
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
        /* Not done in an if-conditional to prevent unnecessary ecrecover evaluation. */

        /* Order must be targeted at this protocol version (this Exchange contract). */
        if (order.exchange != address(this)) {
            return false;
        }

        /* Order must have not been canceled or already filled. */
        if (cancelledOrFinalized[hash]) {
            return false;
        }
        
        /* Order must possess valid sale kind parameter combination. */
        if (!SaleKindInterface.validateParameters(order.side, order.saleKind, order.expirationTime)) {
            return false;
        }

        /* Order authentication. Order must be either:
           (a) sent by maker */
        if (msg.sender == order.maker) {
            return true;
        }
  
        /* (b) previously approved */
        if (approvedOrders[hash]) {
            return true;
        }

        /* or (c) ECDSA-signed by maker. */
        if (ecrecover(hash, sig.v, sig.r, sig.s) == order.maker) {
            return true;
        }

        return false;
    }

    function approveOrder(Order memory order, bool orderbookInclusionDesired)
        internal
    {
        /* CHECKS */

        /* Assert sender is authorized to approve order. */
        require(msg.sender == order.maker);

        /* Calculate order hash. */
        bytes32 hash = hashToSign(order);

        /* Assert order has not already been approved. */
        require(!approvedOrders[hash]);

        /* EFFECTS */
    
        /* Mark order as approved. */
        approvedOrders[hash] = true;
  
        /* Log approval event. Must be split in two due to Solidity stack size limitations. */
        {
            OrderApprovedPartOne(hash, order.exchange, order.maker, order.taker, order.makerFee, order.takerFee, order.feeRecipient, order.side, order.saleKind, order.target, order.howToCall, order.calldata);
        }
        {   
            OrderApprovedPartTwo(hash, order.replacementPattern, order.staticTarget, order.staticExtradata, order.paymentToken, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt, orderbookInclusionDesired);
        }
    }

    function cancelOrder(Order memory order, Sig memory sig) 
        internal
    {
        /* CHECKS */

        /* Calculate order hash. */
        bytes32 hash = requireValidOrder(order, sig);

        /* Assert sender is authorized to cancel order. */
        require(msg.sender == order.maker);
  
        /* EFFECTS */
      
        /* Mark order as cancelled, preventing it from being bid on or matched. */
        cancelledOrFinalized[hash] = true;

        /* Log cancel event. */
        OrderCancelled(hash);
    }

    function bid (Order order, Sig sig, uint amount)
        internal
    {
        /* CHECKS */
 
        /* Calculate order hash. */ 
        bytes32 hash = requireValidOrder(order, sig);

        /* Fetch current top bid, if existent. */
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

        /* Log bid event. */
        OrderBidOn(hash, msg.sender, amount);
    }

    function calculateCurrentPrice (Order order)
        view
        internal  
        returns (uint)
    {
        bytes32 hash = hashOrder(order);
        SaleKindInterface.Bid storage topBid = topBids[hash];
        return SaleKindInterface.calculateFinalPrice(order.side, order.saleKind, order.basePrice, order.extra, order.listingTime, order.expirationTime, topBid);
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

        /* Determine maker/taker and charge fees accordingly. */
        if (sell.feeRecipient != address(0)) {
            /* Sell-side order is maker. */
      
            /* Assert taker fee is less than or equal to maximum fee specified by buyer. */
            require(sell.takerFee <= buy.takerFee);
            
            /* Charge maker fee to seller. */
            chargeFee(sell.maker, sell.feeRecipient, sell.makerFee);

            /* Charge taker fee to buyer. */
            chargeFee(buy.maker, sell.feeRecipient, sell.takerFee);
        } else {
            /* Buy-side order is maker. */

            /* Assert taker fee is less than or equal to maximum fee specified by seller. */
            require(buy.takerFee <= sell.takerFee);

            /* Charge maker fee to buyer. */
            chargeFee(buy.maker, buy.feeRecipient, buy.makerFee);
      
            /* Charge taker fee to seller. */
            chargeFee(sell.maker, buy.feeRecipient, buy.takerFee);
        }

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
            /* Must match maker/taker addresses. */
            (sell.taker == address(0) || sell.taker == buy.maker) &&
            (buy.taker == address(0) || buy.taker == sell.maker) &&
            /* One must be maker and the other must be taker (no bool XOR in Solidity). */
            ((sell.feeRecipient == address(0) && buy.feeRecipient != address(0)) || (sell.feeRecipient != address(0) && buy.feeRecipient == address(0))) &&
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

        /* Execute specified call through proxy.
           Both orders have already been marked as finalized, so they can't be rematched by a reentrant call.
           However, it *is* possible for this call to match other orders - apart from causing unusual log
           order, that shouldn't be a problem. */
        require(proxy.proxy(sell.target, sell.howToCall, sell.calldata));

        /* Static calls are intentionally done after the effectful call so they can check resulting state. */

        /* Handle buy-side static call if specified. */
        if (buy.staticTarget != address(0)) {
            require(staticCall(buy.staticTarget, sell.calldata, buy.staticExtradata));
        }

        /* Handle sell-side static call if specified. */
        if (sell.staticTarget != address(0)) {
            require(staticCall(sell.staticTarget, sell.calldata, sell.staticExtradata));
        }

        /* Log match event. */
        OrdersMatched(buyHash, sellHash);
    }

}
