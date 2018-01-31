/*

  Proxy registry; keeps a mapping of AuthenticatedProxy contracts and a single AuthenticatedLazyBank instance. 
  
  Abstracted away from the Exchange so that other contracts (and future versions of the Exchange) can utilize the same Registry contract.

*/

pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";

import "./AuthenticatedProxy.sol";

contract ProxyRegistry is Ownable {

    /* Authenticated proxies by user. */
    mapping(address => AuthenticatedProxy) public proxies;

    /* Contracts pending access. */
    mapping(address => uint) public pending;

    /* Contracts allowed to call those proxies. */
    mapping(address => bool) public contracts;

    /* Delay period. */
    uint public DELAY_PERIOD = 2 weeks;

    /**
     * Start the process to enable access for specified contract. Subject to delay period.
     *
     * @dev ProxyRegistry owner only
     * @param addr Address to which to grant permissions
     */
    function startGrantAuthentication (address addr)
        public
        onlyOwner
    {
        require(!contracts[addr] && pending[addr] == 0);
        pending[addr] = now;
    }

    /**
     * End the process to nable access for specified contract after delay period has passed.
     *
     * @dev ProxyRegistry owner only
     * @param addr Address to which to grant permissions
     */
    function endGrantAuthentication (address addr)
        public
        onlyOwner
    {
        require(!contracts[addr] && pending[addr] != 0 && pending[addr] < (now + DELAY_PERIOD));
        pending[addr] = 0;
        contracts[addr] = true;
    }

    /**
     * Revoke access for specified contract. Can be done instantly.
     *
     * @dev ProxyRegistry owner only
     * @param addr Address of which to revoke permissions
     */    
    function revokeAuthentication (address addr)
        public
        onlyOwner
    {
        contracts[addr] = false;
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
