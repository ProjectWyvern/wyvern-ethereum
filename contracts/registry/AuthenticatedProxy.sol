/* 

  Proxy contract to hold access to assets on behalf of a user (e.g. ERC20 approve).

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

    address public authAddr;

    enum HowToCall { Call, DelegateCall, StaticCall, Create }

    event ProxiedCall(address indexed dest, HowToCall howToCall, bytes calldata, address indexed created, bool success);
    event AuthAddrChanged(address indexed newAddrAuth);

    function AuthenticatedProxy(address addrUser, address addrAuth) public {
        userAddr = addrUser;
        authAddr = addrAuth;
    }

    function changeAuth(address newAddrAuth) public {
        require(msg.sender == userAddr);
        authAddr = newAddrAuth;
        AuthAddrChanged(newAddrAuth);
    }

    function proxy(address dest, HowToCall howToCall, bytes calldata) public returns (bool result) {
        address created;
        if (howToCall == HowToCall.Call) {
            result = dest.call(calldata);
        } else if (howToCall == HowToCall.DelegateCall) {
            result = dest.delegatecall(calldata);
        } else if (howToCall == HowToCall.StaticCall) {
            // Check this.
            uint len = calldata.length;
            assembly {
                result := staticcall(gas, dest, calldata, len, calldata, 0)
            }
        } else if (howToCall == HowToCall.Create) {
            assembly {
                created := create(0, add(calldata, 0x20), mload(calldata))
            }
            result = created == address(0);
        } else {
            revert();
        }
        ProxiedCall(dest, howToCall, calldata, created, result);
        return result;
    }

}
