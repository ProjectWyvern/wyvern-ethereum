/*
  
  Exchange (outer contract with public functions).
 
*/

pragma solidity 0.4.18;

import "./ExchangeCore.sol";

/**
 * @title Exchange
 * @author Project Wyvern Developers
 */
contract Exchange is ExchangeCore {

    /* Inline library function exposed for testing. */
    function guardedArrayReplace(bytes array, bytes desired, bytes mask)
        public
        pure
        returns (bytes)
    {
        ArrayUtils.guardedArrayReplace(array, desired, mask);
        return array;
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function hashOrder_(
        address[7] addrs,
        uint[7] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes staticExtradata)
        public
        pure
        returns (bytes32)
    { 
        return hashToSign(
          Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], side, saleKind, addrs[4], howToCall, calldata, replacementPattern, addrs[5], staticExtradata, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6])
        );
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function validateOrder_ (
        address[7] addrs,
        uint[7] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes staticExtradata,
        uint8 v,
        bytes32 r,
        bytes32 s)
        view
        public
        returns (bool)
    {
        Order memory order = Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], side, saleKind, addrs[4], howToCall, calldata, replacementPattern, addrs[5], staticExtradata, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6]);
        return validateOrder(
          hashToSign(order),
          order,
          Sig(v, r, s)
        );
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function approveOrder_ (
        address[7] addrs,
        uint[7] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes staticExtradata,
        bool orderbookInclusionDesired) 
        public
    {
        Order memory order = Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], side, saleKind, addrs[4], howToCall, calldata, replacementPattern, addrs[5], staticExtradata, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6]);
        return approveOrder(order, orderbookInclusionDesired);
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function cancelOrder_(
        address[7] addrs,
        uint[7] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes staticExtradata,
        uint8 v,
        bytes32 r,
        bytes32 s)
        public
    {

        return cancelOrder(
          Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], side, saleKind, addrs[4], howToCall, calldata, replacementPattern, addrs[5], staticExtradata, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6]),
          Sig(v, r, s)
        );
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function calculateCurrentPrice_(
        address[7] addrs,
        uint[7] uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata,
        bytes replacementPattern,
        bytes staticExtradata)
        public
        view
        returns (uint)
    {
        return calculateCurrentPrice(
          Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], side, saleKind, addrs[4], howToCall, calldata, replacementPattern, addrs[5], staticExtradata, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6])
        );
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function ordersCanMatch_(
        address[14] addrs,
        uint[14] uints,
        uint8[6] sidesKindsHowToCalls,
        bytes calldataBuy,
        bytes calldataSell,
        bytes replacementPatternBuy,
        bytes replacementPatternSell,
        bytes staticExtradataBuy,
        bytes staticExtradataSell)
        public
        view
        returns (bool)
    {
        Order memory buy = Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], SaleKindInterface.Side(sidesKindsHowToCalls[0]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[1]), addrs[4], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[2]), calldataBuy, replacementPatternBuy, addrs[5], staticExtradataBuy, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6]);
        Order memory sell = Order(addrs[7], addrs[8], addrs[9], uints[7], uints[8], addrs[10], SaleKindInterface.Side(sidesKindsHowToCalls[3]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[4]), addrs[11], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[5]), calldataSell, replacementPatternSell, addrs[12], staticExtradataSell, ERC20(addrs[13]), uints[9], uints[10], uints[11], uints[12], uints[13]);
        return ordersCanMatch(
          buy,
          sell
        );
    }

    function orderCalldataCanMatch(bytes buyCalldata, bytes buyReplacementPattern, bytes sellCalldata, bytes sellReplacementPattern)
        public
        pure
        returns (bool)
    {
        ArrayUtils.guardedArrayReplace(buyCalldata, sellCalldata, buyReplacementPattern);
        ArrayUtils.guardedArrayReplace(sellCalldata, buyCalldata, sellReplacementPattern);
        return ArrayUtils.arrayEq(buyCalldata, sellCalldata);
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function calculateMatchPrice_(
        address[14] addrs,
        uint[14] uints,
        uint8[6] sidesKindsHowToCalls,
        bytes calldataBuy,
        bytes calldataSell,
        bytes replacementPatternBuy,
        bytes replacementPatternSell,
        bytes staticExtradataBuy,
        bytes staticExtradataSell)
        public
        view
        returns (uint)
    {
        Order memory buy = Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], SaleKindInterface.Side(sidesKindsHowToCalls[0]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[1]), addrs[4], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[2]), calldataBuy, replacementPatternBuy, addrs[5], staticExtradataBuy, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6]);
        Order memory sell = Order(addrs[7], addrs[8], addrs[9], uints[7], uints[8], addrs[10], SaleKindInterface.Side(sidesKindsHowToCalls[3]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[4]), addrs[11], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[5]), calldataSell, replacementPatternSell, addrs[12], staticExtradataSell, ERC20(addrs[13]), uints[9], uints[10], uints[11], uints[12], uints[13]);
        return calculateMatchPrice(
          buy,
          sell
        );
    }

    /* Solidity ABI encoding limitation workaround, hopefully temporary. */
    function atomicMatch_(
        address[14] addrs,
        uint[14] uints,
        uint8[6] sidesKindsHowToCalls,
        bytes calldataBuy,
        bytes calldataSell,
        bytes replacementPatternBuy,
        bytes replacementPatternSell,
        bytes staticExtradataBuy,
        bytes staticExtradataSell,
        uint8[2] vs,
        bytes32[4] rss)
        public
    {
        return atomicMatch(
          Order(addrs[0], addrs[1], addrs[2], uints[0], uints[1], addrs[3], SaleKindInterface.Side(sidesKindsHowToCalls[0]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[1]), addrs[4], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[2]), calldataBuy, replacementPatternBuy, addrs[5], staticExtradataBuy, ERC20(addrs[6]), uints[2], uints[3], uints[4], uints[5], uints[6]),
          Sig(vs[0], rss[0], rss[1]),
          Order(addrs[7], addrs[8], addrs[9], uints[7], uints[8], addrs[10], SaleKindInterface.Side(sidesKindsHowToCalls[3]), SaleKindInterface.SaleKind(sidesKindsHowToCalls[4]), addrs[11], AuthenticatedProxy.HowToCall(sidesKindsHowToCalls[5]), calldataSell, replacementPatternSell, addrs[12], staticExtradataSell, ERC20(addrs[13]), uints[9], uints[10], uints[11], uints[12], uints[13]),
          Sig(vs[1], rss[2], rss[3])
        );
    }

}
