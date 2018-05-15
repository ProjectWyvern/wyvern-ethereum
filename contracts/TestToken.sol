/*

  << Test Token (for use with the Test DAO) >>

*/

pragma solidity 0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

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
    constructor () public {
        balances[msg.sender] = MINT_AMOUNT;
        totalSupply_ = MINT_AMOUNT;
    }

}
