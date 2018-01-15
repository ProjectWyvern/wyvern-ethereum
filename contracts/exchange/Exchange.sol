/*

  Decentralized digital item exchange. Supports any digital asset that can be represented on the Ethereum blockchain.

  Let us suppose two agents interacting with a distributed ledger have utility functions preferencing certain states of that ledger over others.
  Aiming to maximize their utility, these agents may construct with their utility functions along with the present ledger state a mapping of state transitions (transactions) to marginal utilities.
  Any composite state transition with positive marginal utility for and enactable by the combined permissions of both agents thus is a mutually desirable trade, and the trustless 
  code execution provided by a distributed ledger renders the requisite atomicity trivial.

  Relative to this model, the present Exchange instantiation makes two concessions to practicality:
  - State transition preferences are not matched directly but instead intermediated by a standard of tokenized value.
  - A small fee is charged in the token of payment, split between protocol development and frontend compensation.

  Solidity presently possesses neither a strong functional typesystem nor runtime reflection (ABI encoding in Solidity), so we must be a bit clever in implementation.
  
*/

pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/token/ERC20.sol";

import "../registry/ProxyRegistry.sol";
import "../common/LazyBank.sol";
import "../common/ArrayUtils.sol";
import "./SaleKindInterface.sol";

/**
 * @title Exchange
 * @author Project Wyvern Developers
 */
contract Exchange is LazyBank {

    /* The token used to pay exchange fees. */
    ERC20 public exchangeTokenAddress;

    /* User registry. */
    ProxyRegistry public registry;

    /* Top bids for all bid-supporting auctions, by hash. */
    mapping(bytes32 => SaleKindInterface.Bid) public topBids;
 
    /* Cancelled / finalized orders, by hash. */
    mapping(bytes32 => bool) cancelledOrFinalized;

    /* Orders verified by on-chain approval (alternative to ECDSA signatures so that smart contracts can place orders directly). */
    mapping(bytes32 => bool) approvedOrders;

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
        /* replacementPattern pattern. */
        bytes replacementPattern;
        /* Order metadata IPFS hash. */
        bytes metadataHash;
        /* Token used to pay for the item. */
        ERC20 paymentToken;
        /* Base price of the item (tokens). */
        uint basePrice;
        /* Base fee of the item (Exchange fee tokens). */
        uint baseFee;
        /* Auction extra parameter - minimum bid increment for English auctions, decay factor for Dutch auctions. */
        uint extra;
        /* Listing timestamp. */
        uint listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint expirationTime;
        /* Order frontend. */
        address frontend;
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
        transferTo(from, to, exchangeTokenAddress, amount);
    }

    function hashOrderPartOne(Order order)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(order.exchange, order.initiator, order.side, order.saleKind, order.target, order.howToCall, order.calldata, order.replacementPattern);
    }

    function hashOrderPartTwo(Order order)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(order.metadataHash, order.paymentToken, order.basePrice, order.baseFee, order.extra, order.listingTime, order.expirationTime, order.frontend, order.salt);
    }

    function hashOrder(Order order)
        internal
        pure
        returns (bytes32)
    {
        /* This is silly, but necessary due to Solidity compiler stack size constraints. */
        return keccak256(hashOrderPartOne(order), hashOrderPartTwo(order));
    }

    function hashOrder_(
        address[5] addrs,
        uint[6] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes metadataHash)
        public
        pure
        returns (bytes32)
    { 
        return hashOrder(
          Order(addrs[0], addrs[1], side, saleKind, addrs[2], howToCall, calldata, replacementPattern, metadataHash, ERC20(addrs[3]), uints[0], uints[1], uints[2], uints[3], uints[4], addrs[4], uints[5])
        );
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
            order.exchange == address(this) &&
            !cancelledOrFinalized[hash] && 
            (approvedOrders[hash] || ecrecover(hash, sig.v, sig.r, sig.s) == order.initiator) &&
            SaleKindInterface.validateParameters(order.side, order.saleKind, order.expirationTime)
        );
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function validateOrder_ (
        address[5] addrs,
        uint[6] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes metadataHash,
        uint8 v,
        bytes32 r,
        bytes32 s)
        view
        public
        returns (bool)
    {
        Order memory order = Order(addrs[0], addrs[1], side, saleKind, addrs[2], howToCall, calldata, replacementPattern, metadataHash, ERC20(addrs[3]), uints[0], uints[1], uints[2], uints[3], uints[4], addrs[4], uints[5]);
        return validateOrder(
          hashToSign(order),
          order,
          Sig(v, r, s)
        );
    }

    function approveOrder(Order memory order, bool orderbookInclusionDesired)
        internal
    {
        require(msg.sender == order.initiator);
        bytes32 hash = hashToSign(order);
        require(!approvedOrders[hash]);
        approvedOrders[hash] = true;
        OrderApproved(hash, msg.sender, order, orderbookInclusionDesired);
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function approveOrder_ (
        address[5] addrs,
        uint[6] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes metadataHash,
        bool orderbookInclusionDesired) 
        public
    {
        Order memory order = Order(addrs[0], addrs[1], side, saleKind, addrs[2], howToCall, calldata, replacementPattern, metadataHash, ERC20(addrs[3]), uints[0], uints[1], uints[2], uints[3], uints[4], addrs[4], uints[5]);
        return approveOrder(order, orderbookInclusionDesired);
    }

    function cancelOrder(Order memory order, Sig memory sig) 
        internal
    {
        /* CHECKS */
        bytes32 hash = requireValidOrder(order, sig);
        require(msg.sender == order.initiator);
  
        /* EFFECTS */
        cancelledOrFinalized[hash] = true;

        OrderCancelled(hash);
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function cancelOrder_(
        address[5] addrs,
        uint[6] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes metadataHash,
        uint8 v,
        bytes32 r,
        bytes32 s)
        public
    {
        return cancelOrder(
          Order(addrs[0], addrs[1], side, saleKind, addrs[2], howToCall, calldata, replacementPattern, metadataHash, ERC20(addrs[3]), uints[0], uints[1], uints[2], uints[3], uints[4], addrs[4], uints[5]),
          Sig(v, r, s)
        );
    }

    function bid (Order order, Sig sig, uint amount)
        internal
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
            unlock(topBid.bidder, order.paymentToken, topBid.amount);
        }

        /* Lock tokens for the new high bidder. */
        lazyLock(msg.sender, order.paymentToken, amount);

        /* Log the bid event. */
        OrderBidOn(hash, msg.sender, amount, now);
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function bid_(
        address[5] addrs,
        uint[6] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes metadataHash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint amount)
        public
    {
        return bid(
          Order(addrs[0], addrs[1], side, saleKind, addrs[2], howToCall, calldata, replacementPattern, metadataHash, ERC20(addrs[3]), uints[0], uints[1], uints[2], uints[3], uints[4], addrs[4], uints[5]),
          Sig(v, r, s),
          amount
        );
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

    function executeFundsTransfer(Order buy, Order sell)
        internal
    {
        /* Fetch top bid, if existent. */
        SaleKindInterface.Bid storage topBid = topBids[hashOrder(sell)];

        /* Calculate match price. */
        uint price = calculateMatchPrice(buy, sell, topBid);

        /* Charge fees. */
        chargeFee(buy.initiator, buy.frontend, buy.baseFee);
        chargeFee(sell.initiator, sell.frontend, sell.baseFee);

        /* Unlock tokens for top bidder, if existent. */
        if (topBid.bidder != address(0)) {
            unlock(topBid.bidder, sell.paymentToken, topBid.amount);
        }

        /* Debit buyer. */
        lazyDebit(buy.initiator, sell.paymentToken, price);

        /* Credit seller. */
        credit(sell.initiator, sell.paymentToken, price);
    }

    function atomicMatch(Order buy, Sig buySig, Order sell, Sig sellSig)
        internal
    {
        /* CHECKS */
      
        bytes32 buyHash = requireValidOrder(buy, buySig);
        bytes32 sellHash = requireValidOrder(sell, sellSig); 

        /* Must be opposite-side. */
        require(buy.side == SaleKindInterface.Side.Buy && sell.side == SaleKindInterface.Side.Sell);

        /* Must use same payment token. */
        require(buy.paymentToken == sell.paymentToken);

        /* Must be settleable. */
        SaleKindInterface.Bid storage topBid = topBids[sellHash];
        require(SaleKindInterface.canSettleOrder(buy.saleKind, sell.initiator, buy.expirationTime, SaleKindInterface.Bid({ bidder: address(0), amount: 0 })));
        require(SaleKindInterface.canSettleOrder(sell.saleKind, buy.initiator, sell.expirationTime, topBid));
        
        /* Must match target. */
        require(buy.target == sell.target);

        /* Must match howToCall. */
        require(buy.howToCall == sell.howToCall);
       
        /* Must match calldata after replacementPattern. */ 
        ArrayUtils.guardedArrayReplace(buy.calldata, sell.calldata, buy.replacementPattern);
        ArrayUtils.guardedArrayReplace(sell.calldata, buy.calldata, sell.replacementPattern);
        require(ArrayUtils.arrayEq(buy.calldata, sell.calldata));

        /* Retrieve proxy (the registry contract is trusted). */
        AuthenticatedProxy proxy = registry.proxies(sell.initiator);

        /* Proxy must exist. */
        require(proxy != address(0));

        /* EFFECTS */

        /* Mark orders as finalized. */
        cancelledOrFinalized[buyHash] = true;
        cancelledOrFinalized[sellHash] = true;

        /* Validate and transfer funds. */ 
        executeFundsTransfer(buy, sell);

        /* INTERACTIONS */

        /* Execute call through proxy. is is though? lazyDebit? safer to reentrancy guard?
           This is the *only* external call to untrusted contract(s) in this function. */
        require(proxy.proxy(sell.target, sell.howToCall, sell.calldata));

        /* Log match event. */
        OrdersMatched(buy, sell);
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function atomicMatch_(
        address[10] addrs,
        uint[12] uints,
        uint8[6] sidesKindsHowToCalls,
        bytes calldataBuy,
        bytes calldataSell,
        bytes replacementPatternBuy,
        bytes replacementPatternSell,
        bytes metadataHashBuy,
        bytes metadataHashSell,
        uint8[2] vs,
        bytes32[4] rss)
        public
    {
        return atomicMatch(
          Order(addrs[0], addrs[1], SaleKindInterface.Side(sidesKindsHowToCalls[0]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[1]), addrs[2], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[2]), calldataBuy, replacementPatternBuy, metadataHashBuy, ERC20(addrs[3]), uints[0], uints[1], uints[2], uints[3], uints[4], addrs[4], uints[5]),
          Sig(vs[0], rss[0], rss[1]),
          Order(addrs[5], addrs[6], SaleKindInterface.Side(sidesKindsHowToCalls[3]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[4]), addrs[7], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[5]), calldataSell, replacementPatternSell, metadataHashSell, ERC20(addrs[8]), uints[6], uints[7], uints[8], uints[9], uints[10], addrs[9], uints[11]),
          Sig(vs[1], rss[2], rss[3])
        );
    }

}
