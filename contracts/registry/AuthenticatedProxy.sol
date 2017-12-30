/* 

  Proxy contract to hold access to assets on behalf a user (e.g. ERC20 approve).

  Includes replay prevention; each signature can only be used once and is only valid for the particular contract specified.

*/

pragma solidity 0.4.18;

import "../common/ArrayUtils.sol";

/**
 * @title AuthenticatedProxy
 * @author Project Wyvern Developers
 */
contract AuthenticatedProxy {

    address public userAddr;

    mapping(bytes32 => bool) sent;

    function AuthenticatedProxy(address addrUser) public {
        userAddr = addrUser;
    }

    function validateAndSend(address dest, bytes calldata, bytes32 signature, uint8 v, bytes32 r, bytes32 s) internal returns (bool) {
        require(!sent[signature]);
        require(ecrecover(signature, v, r, s) == userAddr);
        sent[signature] = true;
        return dest.call(calldata);
    }

    /* User has signed :: Transaction -> Bool.
       Requesting user wants to replace (bytes replace) */
    function proxy(uint id, address dest, bytes calldata, bytes replace, uint start, uint length, uint8 v, bytes32 r, bytes32 s) public returns (bool) {
        require(replace.length == length);
        bytes memory finalCalldata = ArrayUtils.arrayCopy(calldata, replace, start);
        bytes32 signature = keccak256(id, dest, calldata, start, length, msg.sender);
        return validateAndSend(dest, finalCalldata, signature, v, r, s);
    }

    /* User has signed :: Transaction */
    function proxyUnaltered(uint id, address dest, bytes calldata, uint8 v, bytes32 r, bytes32 s) public returns (bool) {
        return proxy(id, dest, calldata, new bytes(0), 0, 0, v, r, s);
    }

}
