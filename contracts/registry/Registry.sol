/*

  Proxy registry; keeps a mapping of AuthenticatedProxy contracts. 
  
  Abstracted away from the Exchange so that other contracts (and future versions of the Exchange) can utilize the same Registry contract.

*/

pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";

import "./AuthenticatedProxy.sol";

contract Registry is Ownable {

    /* Authenticated proxies by user. */
    mapping(address => AuthenticatedProxy) public proxies;

    /* Contracts allowed to call those proxies. */
    mapping(address => bool) public contracts;

    /**
     * Change whether or not a given contract is allowed to access proxies registered with this Registry
     *
     * @dev Registry owner only
     * @param addr Address to set permissions for
     * @param allowed Whether or not that address will be allowed to access proxies
     */    
    function updateContract(address addr, bool allowed)
        public
        onlyOwner
    {
        contracts[addr] = allowed;
    }

    /**
     * Register a proxy contract with this registry
     *
     * @dev Must be called by the user which the proxy is for, creates a new AuthenticatedProxy
     * @return New AuthenticatedProxy contract
     */
    function registerProxy()
        public
        returns (AuthenticatedProxy proxy)
    {
        require(proxies[msg.sender] == address(0));
        proxy = new AuthenticatedProxy(msg.sender, this);
        proxies[msg.sender] = proxy;
        return proxy;
    }

}
