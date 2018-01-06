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

    function WyvernExchange (Registry registryAddress, ERC20 tokenAddress) public {
        owner = msg.sender;
        publicBeneficiary = msg.sender;
        exchangeTokenAddress = tokenAddress;
        registry = registryAddress;
        feeBid = 0;
        feeOwner = 10;
        feePublicBenefit = 10;
        feeSellFrontend = 5;
        feeBuyFrontend = 5;
    }

}
