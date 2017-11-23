/*

  << Project Wyvern Exchange >>

*/

pragma solidity ^0.4.15;

import './exchange/Exchange.sol';

contract WyvernExchange is Exchange {

  string public constant name = "Project Wyvern Exchange";

  function WyvernExchange (ERC20 tokenAddress, uint sellFee, uint bidFee, uint buyFee) {
    exchangeTokenAddress = tokenAddress;
    feeSell = sellFee;
    feeBid = bidFee;
    feeBuy = buyFee;
  }

}
