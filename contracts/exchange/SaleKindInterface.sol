pragma solidity ^0.4.18;

/**
 * @title SaleKindInterface
 * @author Project Wyvern Developers
 */
library SaleKindInterface {

    enum SaleKind { FixedPrice, EnglishAuction, DutchAuction }

    struct Bid {
        /* Address of the bidder. */
        address bidder;
        /* Amount of the bid. */
        uint amount;
        /* Timestamp of bid placement. */
        uint timestamp;
    }   

    function requiredBidPrice(SaleKind saleKind, uint basePrice, uint extra, uint expirationTime, Bid currentTopBid) view internal returns (uint minimumBid) {
        require((saleKind == SaleKind.EnglishAuction) && (now < expirationTime));
        if (currentTopBid.bidder == address(0)) {
            return basePrice;
        } else {
            return currentTopBid.amount + extra;
        }
    }

    function canPurchaseItem(SaleKind saleKind, uint expirationTime, Bid topBid) view internal returns (bool) {
        if (saleKind == SaleKind.EnglishAuction) {
            return ((msg.sender == topBid.bidder) && (now >= expirationTime));
        } else {
            return (now < expirationTime);
        }
    }

    function calculateFinalPrice(SaleKind saleKind, uint basePrice, uint extra, uint listingTime, uint expirationTime, Bid topBid) view internal returns (uint finalPrice) {
        if (saleKind == SaleKind.FixedPrice) {
            return basePrice;
        } else if (saleKind == SaleKind.EnglishAuction) {
            require(topBid.bidder != address(0));
            return topBid.amount;
        } else if (saleKind == SaleKind.DutchAuction) {
            return basePrice * (1 - (extra * (now - listingTime) / (expirationTime - listingTime)));
        } else {
            revert();
        }
    }

}
