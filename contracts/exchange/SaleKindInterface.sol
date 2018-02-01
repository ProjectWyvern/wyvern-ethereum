/*

  Abstract over fixed-price sales and Dutch auctions, with the intent of easily supporting additional methods of sale later.

  Separated into a library for convenience, all the functions are inlined.

  TODO: Nonlinear Dutch auction?

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
     * Currently supported kinds of sale: fixed price, Dutch auction. 
     * English auctions cannot be supported without stronger escrow guarantees.
     * Future interesting options: Vickrey auction.
     */
    enum SaleKind { FixedPrice, DutchAuction }

    function validateParameters(SaleKind saleKind, uint expirationTime) pure internal returns (bool) {
        /* Auctions must have a set expiration date. */
        return (saleKind == SaleKind.FixedPrice || expirationTime > 0);
    }

    /* Precondition: parameters have passed validateParameters. */
    function canSettleOrder(uint listingTime, uint expirationTime) view internal returns (bool) {
        return (listingTime < now) && (expirationTime == 0 || now < expirationTime);
    }

    /* Precondition: parameters have passed validateParameters. */
    function calculateFinalPrice(Side side, SaleKind saleKind, uint basePrice, uint extra, uint listingTime, uint expirationTime) view internal returns (uint finalPrice) {
        if (saleKind == SaleKind.FixedPrice) {
            return basePrice;
        } else if (saleKind == SaleKind.DutchAuction) {
            uint diff = (extra * (now - listingTime) / (expirationTime - listingTime));
            if (side == Side.Sell) {
                /* Sell-side - start price: basePrice. End price: basePrice - extra. */
                return basePrice - diff;
            } else {
                /* Buy-side - start price: basePrice. End price: basePrice + extra. */
                return basePrice + diff;
            }
        }
    }

}
