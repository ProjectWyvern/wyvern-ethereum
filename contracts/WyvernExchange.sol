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

    string public constant version = "2";

    string public constant codename = "Bakunawa";

    /**
     * @dev Initialize a WyvernExchange instance
     * @param registryAddress Address of the registry instance which this Exchange instance will use
     * @param tokenAddress Address of the token used for protocol fees
     */
    function WyvernExchange (ProxyRegistry registryAddress, TokenTransferProxy tokenTransferProxyAddress, ERC20 tokenAddress, address protocolFeeAddress) public {
        registry = registryAddress;
        tokenTransferProxy = tokenTransferProxyAddress;
        exchangeToken = tokenAddress;
        protocolFeeRecipient = protocolFeeAddress;
        owner = msg.sender;
    }

}
