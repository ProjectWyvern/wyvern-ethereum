/*

  << Project Wyvern Exchange >>

*/

pragma solidity 0.4.18;

import "./exchange/Exchange.sol";

/**
 * @title WyvernExchange
 * @author Project Wyvern Developers
 */
contract WyvernExchange is Exchange {

    string public constant name = "Project Wyvern Exchange";

    function WyvernExchange (ProxyRegistry registryAddress, ERC20 tokenAddress, AuthenticatedLazyBank lazyBankAddress) public {
        exchangeTokenAddress = tokenAddress;
        registry = registryAddress;
        bank = lazyBankAddress;
    }

}
