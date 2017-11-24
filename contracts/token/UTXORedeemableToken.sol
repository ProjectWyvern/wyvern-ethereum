pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/StandardToken.sol';

contract UTXORedeemableToken is StandardToken {

  /* UTXO set at creation. */
  mapping(bytes20 => uint) utxoSet;

  /* Multiplier - tokens per Satoshi. */
  uint public multiplier;
 
  /* Starting byte of addresses - e.g. 0x04 for Bitcoin. */
  bytes1 public startingByte;

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

  /* Source: https://ethereum.stackexchange.com/questions/884/how-to-convert-an-address-to-bytes-in-solidity */
  function addressToBytes(address a) constant returns (bytes b){
    assembly {
        let m := mload(0x40)
        mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
        mstore(0x40, add(m, 52))
        b := m
    }
  }

  function publicKeyToBitcoinAddress(bytes pubKey) constant returns (bytes20) {
    return ripemd160(sha256(startingByte, pubKey));
  }

  /*
  function calculateChecksum(bytes20 hashedPublicKey) constant returns (bytes4) {
    return bytes4(sha256(sha256(network, hashedPublicKey)) & mask4);
  }
  */

  /* Claim a UTXO. */
  function claimUTXO (bytes pubKey, uint8 v, bytes32 r, bytes32 s) returns (uint tokensRedeemed) {
    /* Claimant must sign the Ethereum address to which they wish to remit the redeemed tokens. */
    require(ecdsaVerify(addressToBytes(msg.sender), pubKey, v, r, s));

    /* Calculate the original Bitcoin-style address associated with the provided public key. */
    bytes20 originalAddress = publicKeyToBitcoinAddress(pubKey);

    require(utxoSet[originalAddress] != 0);
    
    tokensRedeemed = utxoSet[originalAddress] * multiplier;
    utxoSet[originalAddress] = 0;
    balances[msg.sender] += tokensRedeemed;   
    return tokensRedeemed;
  }

}

/*

  TODO:
    - Merkle tree for all UXTOs in final block (instead of storing balances), keep record of redeemed UXTOs. (??)

    - Immediate release of remaining supply to Wyvern DAO. (phases?)

    - Invariant cap on total redeemable UXTOs (of known supply at block).
    - Indefinite timeline for redeeming Wyvern to ERC20 tokens. 

    - Order of events: deploy token with block state, deploy DAO associated to token, mint DAO tokens (once only).

    - Look at how *Bitcoin* implements address signature verification (they don't know pubkey either?) >= pubkey from ecrecover (duh). Just add command to wyvernd.

    - Testsuite (including order of events!)

*/
