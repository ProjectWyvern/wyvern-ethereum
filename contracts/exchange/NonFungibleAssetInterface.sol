/*

  Do we need this anymore?

*/

pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/ownership/Claimable.sol";

import "../common/ERC721.sol";

/**
 * @title NonFungibleAssetInterface
 * @author Project Wyvern Developers
 */
library NonFungibleAssetInterface {

    enum NonFungibleAssetKind { None, Claimable, ERC721 }

    function currentOwner(NonFungibleAssetKind kind, address asset, uint assetExtra) public view returns (address) {
        if (kind == NonFungibleAssetKind.None) {
            revert();
        } else if (kind == NonFungibleAssetKind.Claimable) {
            return Claimable(asset).owner();
        } else if (kind == NonFungibleAssetKind.ERC721) {
            return ERC721(asset).ownerOf(assetExtra);
        } else {
            revert();
        }  
    }

    function transferOwnership (NonFungibleAssetKind kind, address asset, address newOwner, uint assetExtra) public {
        if (kind == NonFungibleAssetKind.None) {
            return;
        } else if (kind == NonFungibleAssetKind.Claimable) {
            Claimable(asset).transferOwnership(newOwner);
        } else if (kind == NonFungibleAssetKind.ERC721) {
            ERC721(asset).transfer(newOwner, assetExtra);
        } else {
            revert();
        }
    }

    function claimOwnership (NonFungibleAssetKind kind, address asset, uint assetExtra) public {
        if (kind == NonFungibleAssetKind.None) {
            return;
        } else if (kind == NonFungibleAssetKind.Claimable) {
            Claimable(asset).claimOwnership();
        } else if (kind == NonFungibleAssetKind.ERC721) {
            ERC721(asset).takeOwnership(assetExtra);
        } else {
            revert();
        }
    }

}
