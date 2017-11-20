pragma solidity ^0.4.16;

import 'zeppelin-solidity/contracts/token/StandardToken.sol';
import 'zeppelin-solidity/contracts/token/BurnableToken.sol';

contract WYVToken is StandardToken, BurnableToken {

  uint constant public decimals     = 18;
  string constant public name       = "Project Wyvern Token";
  string constant public symbol     = "WYV";

  uint constant public MINT_AMOUNT  = 2000000 * (10 ** decimals);

  function WYVToken() {
    totalSupply = MINT_AMOUNT;
    balances[msg.sender] = totalSupply;
  }

}
