/*

  << Project Wyvern Token (WYV) >>

*/

pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/BurnableToken.sol';

import './token/UTXORedeemableToken.sol';
import './token/DelayedReleaseToken.sol';

/**
  * @title WyvernToken
  * @author Project Wyvern Developers
  *
  */
contract WyvernToken is DelayedReleaseToken, UTXORedeemableToken, BurnableToken {

  uint constant public decimals     = 18;
  string constant public name       = "Project Wyvern Token";
  string constant public symbol     = "WYV";

  uint constant public MULTIPLIER   = 10;
  uint constant public DAO_AMOUNT   = MULTIPLIER * 100000 * (10 ** decimals);
  uint constant public UTXO_AMOUNT  = MULTIPLIER * 1900000 * (10 ** decimals);
  uint constant public MINT_AMOUNT  = DAO_AMOUNT + UTXO_AMOUNT;

  function WyvernToken (bytes32 merkleRoot) {
    /* Configure DelayedReleaseToken. */
    hasBeenReleased = false;
    temporaryAdmin = msg.sender;
    numberOfDelayedTokens = DAO_AMOUNT;

    /* Configure UTXORedeemableToken. */
    rootUTXOMerkleTreeHash = merkleRoot;
    startingByte = 0x49;
    totalSupply = MINT_AMOUNT;
    multiplier = MULTIPLIER * (10 ** decimals) / (10 ** 8);
  }

}
