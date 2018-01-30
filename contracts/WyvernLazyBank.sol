/*

  << Project Wyvern Lazy Bank >>

*/

pragma solidity 0.4.18;

import "./registry/AuthenticatedLazyBank.sol";
import "./registry/ProxyRegistry.sol";

/**
 * @title WyvernLazyBank
 * @author Project Wyvern Developers
 */
contract WyvernLazyBank is AuthenticatedLazyBank {

    string public constant name = "Project Wyvern Lazy Bank";

    function WyvernLazyBank (ProxyRegistry addrRegistry)
        public
    {
        registry = addrRegistry;
    }

}
