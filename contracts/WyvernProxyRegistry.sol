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

    function WyvernProxyRegistry ()
        public
    {
        lazyBank = new AuthenticatedLazyBank(this);
    }

}
