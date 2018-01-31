/*

  << Project Wyvern Proxy Registry >>

*/

pragma solidity 0.4.18;

import "./registry/ProxyRegistry.sol";

/**
 * @title WyvernProxyRegistry
 * @author Project Wyvern Developers
 */
contract WyvernProxyRegistry is ProxyRegistry {

    string public constant name = "Project Wyvern Proxy Registry";

    bool public initialAddressSet = false;

    function WyvernProxyRegistry ()
        public
    {
    }

    function grantInitialAuthentication (address authAddress)
        onlyOwner
        public
    {
        require(!initialAddressSet);
        initialAddressSet = true;
        contracts[authAddress] = true;
    }

}
