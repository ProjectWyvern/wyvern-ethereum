/*

  << Project Wyvern Exchange >>

*/

pragma solidity ^0.4.15;

import './exchange/Exchange.sol';

contract WyvernExchange is Exchange {

  string public constant name = "Project Wyvern Exchange";

  function WyvernExchange (ERC20 tokenAddress, uint listFee, uint bidFee, uint buyFee) {
    exchangeTokenAddress = tokenAddress;
    feeList = listFee;
    feeBid = bidFee;
    feeBuy = buyFee;
  }

}
