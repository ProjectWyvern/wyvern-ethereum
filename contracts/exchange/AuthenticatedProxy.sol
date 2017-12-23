/* 

  Proxy contract to hold access to assets on behalf a user (e.g. ERC20 approve).

  * DOES NOT prevent repeat usage of same txdata

*/

pragma solidity ^0.4.18;

/**
 * @title AuthenticatedProxy
 * @author Project Wyvern Developers
 */
contract AuthenticatedProxy {

    address userAddr;

    address contractAddr;

    function AuthenticatedProxy(address addrUser, address addrContract) public {
        userAddr = addrUser;
        contractAddr = addrContract;
    }

    function proxy(address dest, bytes calldata, uint8 v, bytes32 r, bytes32 s) public returns (bool) {
        require(msg.sender == contractAddr);
        require(ecrecover(keccak256(dest, calldata), v, r, s) == userAddr);
        return dest.call(calldata);
    }

}
