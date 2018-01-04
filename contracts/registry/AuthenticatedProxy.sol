/* 

  Proxy contract to hold access to assets on behalf of a user (e.g. ERC20 approve).

*/

pragma solidity 0.4.19;

import "../common/ArrayUtils.sol";
import "../common/TokenRecipient.sol";

/**
 * @title AuthenticatedProxy
 * @author Project Wyvern Developers
 */
contract AuthenticatedProxy is TokenRecipient {

    address public userAddr;

    address public authAddr;

    enum HowToCall { Call, DelegateCall, StaticCall }

    event ProxiedCall(address indexed dest, HowToCall howToCall, bytes calldata);
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
        ProxiedCall(dest, howToCall, calldata);
        if (howToCall == HowToCall.Call) {
            return dest.call(calldata);
        } else if (howToCall == HowToCall.DelegateCall) {
            return dest.delegatecall(calldata);
        } else if (howToCall == HowToCall.StaticCall) {
            // Check this.
            uint len = calldata.length;
            assembly {
                result := staticcall(gas, dest, calldata, len, calldata, 0)
            }
        } else {
            revert();
        }
    }

}
