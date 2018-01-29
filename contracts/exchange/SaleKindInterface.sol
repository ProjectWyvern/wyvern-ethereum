/*

  Abstract over fixed-price sales, English auctions, and Dutch auctions, with the intent of easily supporting additional methods of sale later.

  Separated into a library for convenience, all the functions are inlined.

*/

pragma solidity 0.4.18;

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
        return (
            /* Only sell-side orders can be English auctions. */
            (saleKind != SaleKind.EnglishAuction || side == Side.Sell) &&
            /* Auctions must have a set expiration date. */
            (saleKind == SaleKind.FixedPrice || expirationTime > 0)
        );
    }

    /* Precondition: parameters have passed validateParameters. */
    function requiredBidPrice(Side side, SaleKind saleKind, uint basePrice, uint extra, uint expirationTime, Bid currentTopBid) view internal returns (uint minimumBid) {
        require((side == Side.Sell) && (saleKind == SaleKind.EnglishAuction) && (now < expirationTime));
        if (currentTopBid.bidder == address(0)) {
            return basePrice;
        } else {
            return currentTopBid.amount + extra;
        }
    }

    /* Precondition: parameters have passed validateParameters. */
    function canSettleOrder(SaleKind saleKind, address counterpart, uint expirationTime, Bid topBid) view internal returns (bool) {
        if (saleKind == SaleKind.EnglishAuction) {
            return ((counterpart == topBid.bidder) && (now >= expirationTime));
        } else {
            return (expirationTime == 0 || now < expirationTime);
        }
    }

    /* Precondition: parameters have passed validateParameters. */
    function calculateFinalPrice(Side side, SaleKind saleKind, uint basePrice, uint extra, uint listingTime, uint expirationTime, Bid topBid) view internal returns (uint finalPrice) {
        if (saleKind == SaleKind.FixedPrice) {
            return basePrice;
        } else if (saleKind == SaleKind.EnglishAuction) {
            require(topBid.bidder != address(0));
            return topBid.amount;
        } else if (saleKind == SaleKind.DutchAuction) {
            uint diff = (extra * (now - listingTime) / (expirationTime - listingTime));
            if (side == Side.Sell) {
                /* Sell-side - start price: basePrice. End price: basePrice - extra. */
                return basePrice - diff;
            } else {
                /* Buy-side - start price: basePrice. End price: basePrice + extra. */
                return basePrice + diff;
            }
        } else {
            revert();
        }
    }

}
