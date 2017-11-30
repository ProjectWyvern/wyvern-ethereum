/*

  Delayed release token - a token which delays initial mint of a specified amount to allow an address to be provided after the token contract is instantiated.

  Used in our case to allow the Wyvern token to be instantiated, the DAO instantiated using the Wyvern token as the share token, and then a supply of WYV minted to the DAO.

*/

pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/StandardToken.sol';

/**
  * @title DelayedReleaseToken
  * @author Project Wyvern Developers
  * 
  */
contract DelayedReleaseToken is StandardToken {

  /* Temporary administrator address, only used for the initial token release. */
  address temporaryAdmin;

  /* Whether or not the delayed token release has occurred. */
  bool hasBeenReleased;

  /* Number of tokens to be released. */
  uint numberOfDelayedTokens;

  /**
   * @dev Release the previously specified amount of tokens to the provided address
   * @param destination Address for which tokens will be released (minted) 
   */
  function releaseTokens(address destination) {
    require(
      (msg.sender == temporaryAdmin) &&
      (!hasBeenReleased)
      );
    hasBeenReleased = true;
    balances[destination] = numberOfDelayedTokens;
  }

}
