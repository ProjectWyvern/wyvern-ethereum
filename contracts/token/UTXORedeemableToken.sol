pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/StandardToken.sol';
import 'zeppelin-solidity/contracts/MerkleProof.sol';

contract UTXORedeemableToken is StandardToken {

  /* Root hash of the UTXO Merkle tree. */
  bytes32 public rootUTXOMerkleTreeHash;

  /* Redeemed UTXOs. */
  mapping(bytes32 => bool) redeemedUTXOs;

  /* Multiplier - tokens per Satoshi. */
  uint public multiplier;

  /* Total tokens redeemed so far. */
  uint public totalRedeemed;

  /* Maximum redeemable tokens. */
  uint public maximumRedeemable;
 
  /* Validate that a provided ECSDA signature was signed by the specified address. */
  function validateSignature (bytes32 hash, uint8 v, bytes32 r, bytes32 s, address expected) constant returns (bool) {
    return ecrecover(hash, v, r, s) == expected;
  }

  /* Convert an uncompressed ECDSA public key into an Ethereum address. */
  function pubKeyToEthereumAddress (bytes pubKey) constant returns (address) {
    return address(uint(keccak256(pubKey)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
  }

  /* Validate that the hash of a provided message was signed by the ECDSA public key associated with the specified Ethereum address. */
  function ecdsaVerify (bytes message, bytes pubKey, uint8 v, bytes32 r, bytes32 s) constant returns (bool) {
    return validateSignature(sha256(message), v, r, s, pubKeyToEthereumAddress(pubKey));
  }

  /* Validate that the hash of a provided address was signed by the ECDSA public key associated with the specified Ethereum address. */
  function ecdsaVerifyAddr (address addr, bytes pubKey, uint8 v, bytes32 r, bytes32 s) constant returns (bool) {
    return validateSignature(sha256(addr), v, r, s, pubKeyToEthereumAddress(pubKey));
  }

  function extract(bytes data, uint pos) constant returns (bytes32 result) { 
    for (uint i = 0; i < 32; i++)
      result ^= (bytes32(0xff00000000000000000000000000000000000000000000000000000000000000) & data[i + pos]) >> (i * 8);
    return result;
  }

  /* Calculate the Bitcoin-style address associated with a raw ECDSA public key. */
  function pubKeyToBitcoinAddress(bytes pubKey) constant returns (bytes20) {
    /* WIF compressed format. */
    uint x = uint(extract(pubKey, 0));
    uint y = uint(extract(pubKey, 32)); 
    uint8 startingByte = y % 2 == 0 ? 0x02 : 0x03;
    return ripemd160(sha256(startingByte, x));
  }

  function verifyProof(bytes proof, bytes32 merkleLeafHash) returns (bool) {
    return MerkleProof.verifyProof(proof, rootUTXOMerkleTreeHash, merkleLeafHash);
  }

  function calculateUTXOMerkleLeafHash(bytes32 txid, bytes20 originalAddress, uint8 outputIndex, uint satoshis) constant returns (bytes32) {
    return sha3(txid, originalAddress, outputIndex, satoshis);
  }

  function verifyUTXO(bytes32 txid, bytes20 originalAddress, uint8 outputIndex, uint satoshis, bytes proof) constant returns (bool) {
    /* Calculate the hash of the Merkle leaf associated with this UTXO. */
    bytes32 merkleLeafHash = keccak256(txid, originalAddress, outputIndex, satoshis);
  
    /* Verify the proof. */
    return verifyUTXOHash(merkleLeafHash, proof);
  }
    
  function verifyUTXOHash(bytes32 merkleLeafHash, bytes proof) constant returns (bool) {
    /* Require that the UTXO has not yet been redeemed and that it exists in the Merkle tree. */
    return (
      (redeemedUTXOs[merkleLeafHash] == false) &&
      verifyProof(proof, merkleLeafHash)
      );
    
    return true;
  }

  /* Redeem a UTXO. */
  function redeemUTXO (bytes32 txid, uint8 outputIndex, uint satoshis, bytes proof, bytes pubKey, uint8 v, bytes32 r, bytes32 s) returns (uint tokensRedeemed) {

    /* Calculate original Bitcoin-style address associated with the provided public key. */
    bytes20 originalAddress = pubKeyToBitcoinAddress(pubKey);

    /* Calculate the UTXO Merkle leaf hash. */
    bytes32 merkleLeafHash = keccak256(txid, originalAddress, outputIndex, satoshis);

    /* Verify that the UTXO can be redeemed. */
    require(verifyUTXOHash(merkleLeafHash, proof));

    /* Claimant must sign the Ethereum address to which they wish to remit the redeemed tokens. */
    require(ecdsaVerifyAddr(msg.sender, pubKey, v, r, s));

    /* Mark the UTXO as redeemed. */
    redeemedUTXOs[merkleLeafHash] = true;

    /* Calculate the redeemed tokens. */
    tokensRedeemed = satoshis * multiplier;

    /* Track total redeemed tokens. */
    totalRedeemed += tokensRedeemed;

    /* Sanity check. */
    require(totalRedeemed <= maximumRedeemable);

    /* Credit the redeemer. */ 
    balances[msg.sender] += tokensRedeemed;   
  
    /* Return the number of tokens redeemed. */
    return tokensRedeemed;

  }

}
