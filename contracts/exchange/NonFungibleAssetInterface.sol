pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/ownership/Claimable.sol";

/**
 * @title NonFungibleAssetInterface
 * @author Project Wyvern Developers
 */
library NonFungibleAssetInterface {

    enum NonFungibleAssetKind { None, Claimable, ERC721 }

    function currentOwner(NonFungibleAssetKind kind, address asset) public view returns (address) {
        if (kind == NonFungibleAssetKind.None) {
            revert();
        } else if (kind == NonFungibleAssetKind.Claimable) {
            return Claimable(asset).owner();
        } else {
            revert();
        }  
    }

    function pendingOwner(NonFungibleAssetKind kind, address asset) public view returns (address) {
        if (kind == NonFungibleAssetKind.None) {
            revert();
        } else if (kind == NonFungibleAssetKind.Claimable) {
            return Claimable(asset).pendingOwner();
        } else {
            revert();
        }
    }

    function transferOwnership (NonFungibleAssetKind kind, address asset, address newOwner) public {
        if (kind == NonFungibleAssetKind.None) {
            return;
        } else if (kind == NonFungibleAssetKind.Claimable) {
            Claimable(asset).transferOwnership(newOwner);
        } else {
            revert();
        }
    }

    function claimOwnership (NonFungibleAssetKind kind, address asset) public {
        if (kind == NonFungibleAssetKind.None) {
            return;
        } else if (kind == NonFungibleAssetKind.Claimable) {
            Claimable(asset).claimOwnership();
        } else {
            revert();
        }
    }

}
