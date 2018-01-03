/* 

  Proxy contract to hold access to assets on behalf of a user (e.g. ERC20 approve).

  Includes replay prevention; each signature can only be used once and is only valid for the particular contract specified.

*/

pragma solidity 0.4.18;

import "../common/ArrayUtils.sol";
import "../common/TokenRecipient.sol";

/**
 * @title AuthenticatedProxy
 * @author Project Wyvern Developers
 */
contract AuthenticatedProxy is TokenRecipient {

    address public userAddr;

    mapping(bytes32 => bool) sent;

    event ProxiedCall(address indexed dest, bytes calldata, bytes32 signature);

    function AuthenticatedProxy(address addrUser) public {
        userAddr = addrUser;
    }

    function validateAndSend(address dest, bytes calldata, bytes32 signature, uint8 v, bytes32 r, bytes32 s) internal returns (bool) {
        require(!sent[signature]);
        require(ecrecover(signature, v, r, s) == userAddr);
        sent[signature] = true;
        ProxiedCall(dest, calldata, signature);
        return dest.call(calldata);
    }

    /* User has signed :: Transaction -> Bool.
       Requesting user wants to replace (bytes replace) */
    function proxy(uint id, address dest, bytes calldata, bytes replace, uint start, uint length, uint8 v, bytes32 r, bytes32 s) public returns (bool) {
        require(replace.length == length);
        bytes memory finalCalldata = ArrayUtils.arrayCopy(calldata, replace, start);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 signature = keccak256(prefix, keccak256(id, dest, calldata, start, length, msg.sender));
        return validateAndSend(dest, finalCalldata, signature, v, r, s);
    }

    /* User has signed :: Transaction */
    function proxyUnaltered(uint id, address dest, bytes calldata, uint8 v, bytes32 r, bytes32 s) public returns (bool) {
        return proxy(id, dest, calldata, new bytes(0), 0, 0, v, r, s);
    }

}
