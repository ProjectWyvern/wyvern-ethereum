/*

  Authenticated lazy bank.

*/

pragma solidity 0.4.18;

import "../common/LazyBank.sol";
import "./ProxyRegistry.sol";

/**
 * @title AuthenticatedLazyBank
 * @author Project Wyvern Developers
 */
contract AuthenticatedLazyBank is LazyBank {

    ProxyRegistry public registry;

    modifier withRegistryAuth {
        require(registry.contracts(msg.sender));
        _;
    }

    function AuthenticatedLazyBank(ProxyRegistry addrRegistry)
        public
    {
        registry = addrRegistry;
    }

    function _credit(address user, ERC20 token, uint amount)
        public
        withRegistryAuth
    {
        credit(user, token, amount);
    }

    function _lazyDebit(address user, ERC20 token, uint amount)
        public
        withRegistryAuth
    {
        lazyDebit(user, token, amount);
    }

    function _transferTo(address from, address to, ERC20 token, uint amount)
        public
        withRegistryAuth
    {
        transferTo(from, to, token, amount);
    }

    function _lazyLock(address user, ERC20 token, uint amount)
        public
        withRegistryAuth
    {
        lazyLock(user, token, amount);
    }

    function _unlock(address user, ERC20 token, uint amount)
        public
        withRegistryAuth
    {
        unlock(user, token, amount);
    }

}
