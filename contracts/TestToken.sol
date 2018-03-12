/*

  << Test Token (for use with the Test DAO) >>

*/

pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/token/StandardToken.sol";

/**
  * @title TestToken
  * @author Project Wyvern Developers
  */
contract TestToken is StandardToken {

    uint constant public decimals     = 18;
    string constant public name       = "Test Token";
    string constant public symbol     = "TST";

    uint constant public MINT_AMOUNT  = 20000000 * (10 ** decimals);

    /**
      * @dev Initialize the test token
      */
    function TestToken () public {
        balances[msg.sender] = MINT_AMOUNT;
        totalSupply = MINT_AMOUNT;
    }

}
