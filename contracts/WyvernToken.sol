/*

  << Project Wyvern Token (WYV) >>

*/

pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/BurnableToken.sol';

import './token/UTXORedeemableToken.sol';

contract WyvernToken is UTXORedeemableToken, BurnableToken {

  uint constant public decimals     = 18;
  string constant public name       = "Project Wyvern Token";
  string constant public symbol     = "WYV";

  uint constant public MINT_AMOUNT  = 20000000 * (10 ** decimals);

  function WyvernToken () {
    startingByte = 0x49;
    totalSupply = MINT_AMOUNT;
    multiplier = 10 * (10 ** decimals) / (10 ** 8);
    balances[msg.sender] = totalSupply;
  }

}
