pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/StandardToken.sol';
import 'zeppelin-solidity/contracts/MerkleProof.sol';

contract UTXORedeemableToken is StandardToken {

  /* Root hash of the UTXO Merkle tree, must be initialized by token constructor. */
  bytes32 public rootUTXOMerkleTreeHash;

  /* Redeemed UTXOs. */
  mapping(bytes32 => bool) redeemedUTXOs;

  /* Multiplier - tokens per Satoshi, must be initialized by token constructor. */
  uint public multiplier;

  /* Total tokens redeemed so far. */
  uint public totalRedeemed = 0;

  /* Maximum redeemable tokens, must be initialized by token constructor. */
  uint public maximumRedeemable;

  /* Redemption event, containing all relevant data for later analysis if desired. */
  event UTXORedeemed(bytes32 txid, uint8 outputIndex, uint satoshis, bytes proof, bytes pubKey, uint8 v, bytes32 r, bytes32 s, address indexed redeemer, uint numberOfTokens);

  /**
   * @dev Extract a bytes32 subarray from an arbitrary length bytes array.
   * @param data Bytes array from which to extract the subarray
   * @param pos Starting position from which to copy
   * @return Extracted length 32 byte array
   */
  function extract(bytes data, uint pos) constant returns (bytes32 result) { 
    for (uint i = 0; i < 32; i++)
      result ^= (bytes32(0xff00000000000000000000000000000000000000000000000000000000000000) & data[i + pos]) >> (i * 8);
    return result;
  }
 
  /**
   * @dev Validate that a provided ECSDA signature was signed by the specified address
   * @param hash Hash of signed data
   * @param v v parameter of ECDSA signature
   * @param r r parameter of ECDSA signature
   * @param s s parameter of ECDSA signature
   * @param expected Address claiming to have created this signature
   * @return Whether or not the signature was valid
   */
  function validateSignature (bytes32 hash, uint8 v, bytes32 r, bytes32 s, address expected) constant returns (bool) {
    return ecrecover(hash, v, r, s) == expected;
  }

  /**
   * @dev Validate that the hash of a provided address was signed by the ECDSA public key associated with the specified Ethereum address
   * @param addr Address signed
   * @param pubKey Uncompressed ECDSA public key claiming to have created this signature
   * @param v v parameter of ECDSA signature
   * @param r r parameter of ECDSA signature
   * @param s s parameter of ECDSA signature
   * @return Whether or not the signature was valid
   */
  function ecdsaVerify (address addr, bytes pubKey, uint8 v, bytes32 r, bytes32 s) constant returns (bool) {
    return validateSignature(sha256(addr), v, r, s, pubKeyToEthereumAddress(pubKey));
  }

  /**
   * @dev Convert an uncompressed ECDSA public key into an Ethereum address
   * @param pubKey Uncompressed ECDSA public key to convert
   * @return Ethereum address generated from the ECDSA public key
   */
  function pubKeyToEthereumAddress (bytes pubKey) constant returns (address) {
    return address(uint(keccak256(pubKey)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
  }

  /**
   * @dev Calculate the Bitcoin-style address associated with an uncompressed ECDSA public key
   * @param pubKey Compressed ECDSA public key to convert
   * @return Raw Bitcoin address (no base58-check encoding)
   */
  function pubKeyToBitcoinAddress(bytes pubKey) constant returns (bytes20) {
    /* The address is encoded from a compressed public key, so we need to compress the public key. */
    uint x = uint(extract(pubKey, 0));
    uint y = uint(extract(pubKey, 32)); 
    uint8 startingByte = y % 2 == 0 ? 0x02 : 0x03;
    return ripemd160(sha256(startingByte, x));
  }

  /**
   * @dev Verify a Merkle proof using the UTXO Merkle tree
   * @param proof Generated Merkle tree proof
   * @param merkleLeafHash Hash asserted to be present in the Merkle tree
   * @return Whether or not the proof is valid
   */
  function verifyProof(bytes proof, bytes32 merkleLeafHash) returns (bool) {
    return MerkleProof.verifyProof(proof, rootUTXOMerkleTreeHash, merkleLeafHash);
  }

  /**
   * @dev Convenience helper function to check if a UTXO can be redeemed
   * @param txid Transaction hash
   * @param originalAddress Raw Bitcoin address (no base58-check encoding)
   * @param outputIndex Output index of UTXO
   * @param satoshis Amount of UTXO in satoshis
   * @param proof Merkle tree proof
   * @return Whether or not the UTXO can be redeemed
   */
  function verifyUTXO(bytes32 txid, bytes20 originalAddress, uint8 outputIndex, uint satoshis, bytes proof) constant returns (bool) {
    /* Calculate the hash of the Merkle leaf associated with this UTXO. */
    bytes32 merkleLeafHash = keccak256(txid, originalAddress, outputIndex, satoshis);
  
    /* Verify the proof. */
    return verifyUTXOHash(merkleLeafHash, proof);
  }
    
  /**
   * @dev Verify that a UTXO with the specified Merkle leaf hash can be redeemed
   * @param merkleLeafHash Merkle tree hash of the UTXO to be checked
   * @param proof Merkle tree proof
   * @return Whether or not the UTXO with the specified hash can be redeemed
   */
  function verifyUTXOHash(bytes32 merkleLeafHash, bytes proof) constant returns (bool) {
    /* Require that the UTXO has not yet been redeemed and that it exists in the Merkle tree. */
    return (
      (redeemedUTXOs[merkleLeafHash] == false) &&
      verifyProof(proof, merkleLeafHash)
      );
    
    return true;
  }

  /**
   * @dev Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address
   * @param txid Transaction hash
   * @param outputIndex Output index of the UTXO
   * @param satoshis Amount of UTXO in satoshis
   * @param proof Merkle tree proof
   * @param pubKey Uncompressed ECDSA public key to which the UTXO was sent
   * @param v v parameter of ECDSA signature
   * @param r r parameter of ECDSA signature
   * @param s s parameter of ECDSA signature
   * @return The number of tokens redeemed, if successful
   */
  function redeemUTXO (bytes32 txid, uint8 outputIndex, uint satoshis, bytes proof, bytes pubKey, uint8 v, bytes32 r, bytes32 s) returns (uint tokensRedeemed) {

    /* Calculate original Bitcoin-style address associated with the provided public key. */
    bytes20 originalAddress = pubKeyToBitcoinAddress(pubKey);

    /* Calculate the UTXO Merkle leaf hash. */
    bytes32 merkleLeafHash = keccak256(txid, originalAddress, outputIndex, satoshis);

    /* Verify that the UTXO can be redeemed. */
    require(verifyUTXOHash(merkleLeafHash, proof));

    /* Claimant must sign the Ethereum address to which they wish to remit the redeemed tokens. */
    require(ecdsaVerify(msg.sender, pubKey, v, r, s));

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

    /* Mark the event. */
    UTXORedeemed(txid, outputIndex, satoshis, proof, pubKey, v, r, s, msg.sender, tokensRedeemed);
  
    /* Return the number of tokens redeemed. */
    return tokensRedeemed;

  }

}
