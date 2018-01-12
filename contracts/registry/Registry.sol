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
    
    function updateContract(address addr, bool allowed)
        public
        onlyOwner
    {
        contracts[addr] = allowed;
    }

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
