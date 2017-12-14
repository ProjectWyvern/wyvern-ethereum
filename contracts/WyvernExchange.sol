/*

  << Project Wyvern Exchange >>

*/

pragma solidity ^0.4.18;

import "./exchange/Exchange.sol";

/**
 * @title WyvernExchange
 * @author Project Wyvern Developers
 */
contract WyvernExchange is Exchange {

    string public constant name = "Project Wyvern Exchange";

    function WyvernExchange (ERC20 tokenAddress, uint listFee, uint bidFee, uint buyFee) public {
        exchangeTokenAddress = tokenAddress;
        feeList = listFee;
        feeBid = bidFee;
        feeBuy = buyFee;
    }

}
