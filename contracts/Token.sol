pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/StandardToken.sol';
import 'zeppelin-solidity/contracts/token/BurnableToken.sol';

contract WYVToken is StandardToken, BurnableToken {

  uint constant public decimals     = 18;
  string constant public name       = "Project Wyvern Token";
  string constant public symbol     = "WYV";

  uint constant public MINT_AMOUNT  = 2000000 * (10 ** decimals);

  /* Validate that a provided ECSDA signature was signed by the specified address. */
  function validateSignature (bytes32 hash, uint8 v, bytes32 r, bytes32 s, address expected) constant returns (bool) {
    return ecrecover(hash, v, r, s) == expected;
  }

  /* Convert an uncompressed ECDSA public key into an Ethereum address. */
  function pubKeyToAddress (bytes pubKey) constant returns (address) {
    return address(uint(keccak256(pubKey)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
  }

  /* Validate that the hash of a provided message was signed by the specified ECDSA public key. */
  function ecdsaVerify (bytes message, bytes pubKey, uint8 v, bytes32 r, bytes32 s) constant returns (bool) {
    return validateSignature(sha256(message), v, r, s, pubKeyToAddress(pubKey));
  }

  function WYVToken() {
    totalSupply = MINT_AMOUNT;
    balances[msg.sender] = totalSupply;
  }

}

/*

  TODO:
    - Merkle tree for all UXTOs in final block (instead of storing balances), keep record of redeemed UXTOs.
    - Caller must prove (a) existence of UXTO and (b) ownership of address.
    - Immediate release of remaining supply to Wyvern DAO.
    - Invariant cap on total redeemable UXTOs (of known supply at block).
    - Indefinite timeline for redeeming Wyvern to ERC20 tokens. 

    - Order of events: deploy token with block state, deploy DAO associated to token, mint DAO tokens (once only).

    - Look at how *Bitcoin* implements address signature verification (they don't know pubkey either?)

    - Testsuite (including order of events!)

*/
