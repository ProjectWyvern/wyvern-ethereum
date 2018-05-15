/*

  << Project Wyvern Token (WYV) >>

*/

pragma solidity 0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";

import "./token/UTXORedeemableToken.sol";
import "./token/DelayedReleaseToken.sol";

/**
  * @title WyvernToken
  * @author Project Wyvern Developers
  */
contract WyvernToken is DelayedReleaseToken, UTXORedeemableToken, BurnableToken {

    uint constant public decimals     = 18;
    string constant public name       = "Project Wyvern Token";
    string constant public symbol     = "WYV";

    /* Amount of tokens per Wyvern. */
    uint constant public MULTIPLIER       = 1;

    /* Constant for conversion from satoshis to tokens. */
    uint constant public SATS_TO_TOKENS   = MULTIPLIER * (10 ** decimals) / (10 ** 8);

    /* Total mint amount, in tokens (will be reached when all UTXOs are redeemed). */
    uint constant public MINT_AMOUNT      = 2000000 * MULTIPLIER * (10 ** decimals);

    /**
      * @dev Initialize the Wyvern token
      * @param merkleRoot Merkle tree root of the UTXO set
      * @param totalUtxoAmount Total satoshis of the UTXO set
      */
    constructor (bytes32 merkleRoot, uint totalUtxoAmount) public {
        /* Total number of tokens that can be redeemed from UTXOs. */
        uint utxoTokens = SATS_TO_TOKENS * totalUtxoAmount;

        /* Configure DelayedReleaseToken. */
        temporaryAdmin = msg.sender;
        numberOfDelayedTokens = MINT_AMOUNT - utxoTokens;

        /* Configure UTXORedeemableToken. */
        rootUTXOMerkleTreeHash = merkleRoot;
        totalSupply_ = MINT_AMOUNT;
        maximumRedeemable = utxoTokens;
        multiplier = SATS_TO_TOKENS;
    }

}
