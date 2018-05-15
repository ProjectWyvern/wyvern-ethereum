/*

  DELEGATECALL proxy contract.
  Primarily intended to enable easy atomic composition of future transactions (unknown at the time of proxy creation).
  Example: atomically deploying a new contract and changing ENS name resolution to point to it.
  Holds no state and does not capture call results.

*/

pragma solidity 0.4.23;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "../common/TokenRecipient.sol";

/**
 * @title DelegateProxy
 * @author Project Wyvern Developers
 */
contract DelegateProxy is TokenRecipient, Ownable {

    /**
     * Execute a DELEGATECALL from the proxy contract
     *
     * @dev Owner only
     * @param dest Address to which the call will be sent
     * @param calldata Calldata to send
     * @return Result of the delegatecall (success or failure)
     */
    function delegateProxy(address dest, bytes calldata)
        public
        onlyOwner
        returns (bool result)
    {
        return dest.delegatecall(calldata);
    }

    /**
     * Execute a DELEGATECALL and assert success
     *
     * @dev Same functionality as `delegateProxy`, just asserts the return value
     * @param dest Address to which the call will be sent
     * @param calldata Calldata to send
     */
    function delegateProxyAssert(address dest, bytes calldata)
        public
    {
        require(delegateProxy(dest, calldata));
    }

}
