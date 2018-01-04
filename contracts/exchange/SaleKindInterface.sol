/*

  Abstract over fixed-price sales and various kinds of auction.

  Separated into a library for convenience, all the functions are inlined.

*/

pragma solidity 0.4.19;

/**
 * @title SaleKindInterface
 * @author Project Wyvern Developers
 */
library SaleKindInterface {

    /**
     * Side: buy or sell.
     */
    enum Side { Buy, Sell }

    /**
     * Currently supported kinds of sale: fixed price, English auction, Dutch auction. 
     * Future interesting options: Vickrey auction.
     */
    enum SaleKind { FixedPrice, EnglishAuction, DutchAuction }

    struct Bid {
        /* Address of the bidder. */
        address bidder;
        /* Amount of the bid. */
        uint amount;
    }

    function validateParameters(Side side, SaleKind saleKind, uint expirationTime) pure internal returns (bool) {
        return (saleKind != SaleKind.EnglishAuction || expirationTime > 0);
    }

    function requiredBidPrice(Side side, SaleKind saleKind, uint basePrice, uint extra, uint expirationTime, Bid currentTopBid) view internal returns (uint minimumBid) {
        require((side == Side.Sell) && (saleKind == SaleKind.EnglishAuction) && (now < expirationTime));
        if (currentTopBid.bidder == address(0)) {
            return basePrice;
        } else {
            return currentTopBid.amount + extra;
        }
    }

    function canSettleOrder(Side side, SaleKind saleKind, address counterpart, uint expirationTime, Bid topBid) view internal returns (bool) {
        if (saleKind == SaleKind.EnglishAuction) {
            return ((counterpart == topBid.bidder) && (now >= expirationTime));
        } else {
            return (expirationTime == 0 || now < expirationTime);
        }
    }

    function calculateFinalPrice(Side side, SaleKind saleKind, uint basePrice, uint extra, uint listingTime, uint expirationTime, Bid topBid) view internal returns (uint finalPrice) {
        if (saleKind == SaleKind.FixedPrice) {
            return basePrice;
        } else if (saleKind == SaleKind.EnglishAuction) {
            require(topBid.bidder != address(0));
            return topBid.amount;
        } else if (saleKind == SaleKind.DutchAuction) {
            /* Start price: basePrice. End price: basePrice - extra. */
            return basePrice - (extra * (now - listingTime) / (expirationTime - listingTime));
        } else {
            revert();
        }
    }

}
