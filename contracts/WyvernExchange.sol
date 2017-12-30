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

    function WyvernExchange (Registry registryAddress, ERC20 tokenAddress, uint listFee, uint bidFee, uint buyFee) public {
        owner = msg.sender;
        publicBeneficiary = msg.sender;
        exchangeTokenAddress = tokenAddress;
        registry = registryAddress;
        feeList = listFee;
        feeBid = bidFee;
        feeBuy = buyFee;
        feeOwner = 10;
        feePublicBenefit = 10;
        feeFrontend = 10;
    }

}
