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
 
  /* Starting byte of addresses - e.g. 0x04 for Bitcoin. */
  bytes1 public startingByte;

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

  /* Source: https://ethereum.stackexchange.com/questions/884/how-to-convert-an-address-to-bytes-in-solidity */
  function addressToBytes(address a) constant returns (bytes b){
    assembly {
        let m := mload(0x40)
        mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
        mstore(0x40, add(m, 52))
        b := m
    }
  }

  /* Calculate the Bitcoin-style address associated with a raw ECDSA public key. */
  function pubKeyToBitcoinAddress(bytes pubKey) constant returns (bytes20) {
    return ripemd160(sha256(startingByte, pubKey));
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
    require(verifyUTXO(txid, originalAddress, outputIndex, satoshis, proof));

    /* Claimant must sign the Ethereum address to which they wish to remit the redeemed tokens. */
    require(ecdsaVerify(addressToBytes(msg.sender), pubKey, v, r, s));

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
