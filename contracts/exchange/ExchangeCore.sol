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
import "../common/ArrayUtils.sol";
import "../common/ReentrancyGuarded.sol";
import "./SaleKindInterface.sol";

/**
 * @title ExchangeCore
 * @author Project Wyvern Developers
 */
contract ExchangeCore is ReentrancyGuarded {

    /* The token used to pay exchange fees. */
    ERC20 public exchangeToken;

    /* User registry. */
    ProxyRegistry public registry;

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
    event OrdersMatched           (bytes32 indexed buyHash, bytes32 indexed sellHash);

    function chargeFee(address from, address to, uint amount)
        internal
    {
        if (amount > 0) {
            require(exchangeToken.transferFrom(from, to, amount));
        }
    }

    function staticCall(address target, bytes memory calldata, bytes memory extradata)
        internal
        view
        returns (bool result)
    {
        bytes memory combined = new bytes(calldata.length + extradata.length);
        uint len = combined.length;
        for (uint i = 0; i < extradata.length; i++) {
            combined[i] = extradata[i];
        }
        for (uint j = 0; j < calldata.length; j++) {
            combined[j + extradata.length] = calldata[j];
        }
        assembly {
            result := staticcall(gas, target, combined, len, combined, 0)
        }
        return result;
    }

    function hashOrderPartOne(Order memory order)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(order.exchange, order.maker, order.taker, order.makerFee, order.takerFee, order.feeRecipient, order.side, order.saleKind, order.target, order.howToCall, order.calldata, order.replacementPattern);
    }

    function hashOrderPartTwo(Order memory order)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(order.staticTarget, order.staticExtradata, order.paymentToken, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt);
    }

    function hashToSign(Order memory order)
        internal
        pure
        returns (bytes32)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 hash = keccak256(prefix, hashOrderPartOne(order), hashOrderPartTwo(order));
        return hash;
    }

    function requireValidOrder(Order memory order, Sig memory sig)
        internal
        view
        returns (bytes32)
    {
        bytes32 hash = hashToSign(order);
        require(validateOrder(hash, order, sig));
        return hash;
    }

    function validateOrder(bytes32 hash, Order memory order, Sig memory sig) 
        internal
        view
        returns (bool)
    {
        /* Not done in an if-conditional to prevent unnecessary ecrecover evaluation, which seems to happen even though it should short-circuit. */

        /* Order must be targeted at this protocol version (this Exchange contract). */
        if (order.exchange != address(this)) {
            return false;
        }

        /* Order must have not been canceled or already filled. */
        if (cancelledOrFinalized[hash]) {
            return false;
        }
        
        /* Order must possess valid sale kind parameter combination. */
        if (!SaleKindInterface.validateParameters(order.saleKind, order.expirationTime)) {
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

    function calculateCurrentPrice (Order memory order)
        internal  
        view
        returns (uint)
    {
        return SaleKindInterface.calculateFinalPrice(order.side, order.saleKind, order.basePrice, order.extra, order.listingTime, order.expirationTime);
    }

    function calculateMatchPrice(Order memory buy, Order memory sell)
        view
        internal
        returns (uint)
    {
        /* Calculate sell price. */
        uint sellPrice = SaleKindInterface.calculateFinalPrice(sell.side, sell.saleKind, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime);

        /* Calculate buy price. */
        uint buyPrice = SaleKindInterface.calculateFinalPrice(buy.side, buy.saleKind, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime);

        /* Require price cross. */
        require(buyPrice >= sellPrice);
        
        /* Maker/taker priority. */
        return sell.feeRecipient != address(0) ? sellPrice : buyPrice;
    }

    function executeFundsTransfer(Order memory buy, Order memory sell)
        internal
    {
        /* Calculate match price. */
        uint price = calculateMatchPrice(buy, sell);

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

        if (price > 0) {
            /* Debit buyer and credit seller. */
            require(sell.paymentToken.transferFrom(buy.maker, sell.maker, price));
        }
    }

    function ordersCanMatch(Order memory buy, Order memory sell)
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
            SaleKindInterface.canSettleOrder(buy.listingTime, buy.expirationTime) &&
            /* Sell-side order must be settleable. */
            SaleKindInterface.canSettleOrder(sell.listingTime, sell.expirationTime)
        );
    }

    function atomicMatch(Order memory buy, Sig memory buySig, Order memory sell, Sig memory sellSig)
        internal
        reentrancyGuard
    {
        /* CHECKS */
      
        bytes32 buyHash = requireValidOrder(buy, buySig);
        bytes32 sellHash = requireValidOrder(sell, sellSig); 
        
        /* Must be matchable. */
        require(ordersCanMatch(buy, sell));
      
        /* Must match calldata after replacement, if specified. */ 
        if (buy.replacementPattern.length > 0) {
          ArrayUtils.guardedArrayReplace(buy.calldata, sell.calldata, buy.replacementPattern);
        }
        if (sell.replacementPattern.length > 0) {
          ArrayUtils.guardedArrayReplace(sell.calldata, buy.calldata, sell.replacementPattern);
        }
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
        executeFundsTransfer(buy, sell);

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
