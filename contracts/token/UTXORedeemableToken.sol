/*

  UTXO redeemable token.

  This is a token extension to allow porting a Bitcoin or Bitcoin-fork sourced UTXO set to an ERC20 token through redemption of individual UTXOs in the token contract.
    
  Owners of UTXOs in a chosen final set (where "owner" is simply anyone who could have spent the UTXO) are allowed to redeem (mint) a number of tokens proportional to the satoshi amount of the UTXO.

  Notes

    - This method *does not* provision for special Bitcoin scripts (e.g. multisig addresses).
    - Pending transactions are public, so the UTXO redemption transaction must work *only* for an Ethereum address belonging to the same person who owns the UTXO.
      This is enforced by requiring that the redeeemer sign their Ethereum address with their Bitcoin (original-chain) private key.
    - We cannot simply store the UTXO set, as that would be far too expensive. Instead we compute a Merkle tree for the entire UTXO set at the chain state which is to be ported,
      store only the root of that Merkle tree, and require UTXO claimants prove that the UTXO they wish to claim is present in the tree.

*/

pragma solidity 0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/MerkleProof.sol";

/**
  * @title UTXORedeemableToken
  * @author Project Wyvern Developers
  */
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
    event UTXORedeemed(bytes32 txid, uint8 outputIndex, uint satoshis, bytes32[] proof, bytes pubKey, uint8 v, bytes32 r, bytes32 s, address indexed redeemer, uint numberOfTokens);

    /**
     * @dev Extract a bytes32 subarray from an arbitrary length bytes array.
     * @param data Bytes array from which to extract the subarray
     * @param pos Starting position from which to copy
     * @return Extracted length 32 byte array
     */
    function extract(bytes data, uint pos) private pure returns (bytes32 result) { 
        for (uint i = 0; i < 32; i++) {
            result ^= (bytes32(0xff00000000000000000000000000000000000000000000000000000000000000) & data[i + pos]) >> (i * 8);
        }
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
    function validateSignature (bytes32 hash, uint8 v, bytes32 r, bytes32 s, address expected) public pure returns (bool) {
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
    function ecdsaVerify (address addr, bytes pubKey, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        return validateSignature(sha256(addr), v, r, s, pubKeyToEthereumAddress(pubKey));
    }

    /**
     * @dev Convert an uncompressed ECDSA public key into an Ethereum address
     * @param pubKey Uncompressed ECDSA public key to convert
     * @return Ethereum address generated from the ECDSA public key
     */
    function pubKeyToEthereumAddress (bytes pubKey) public pure returns (address) {
        return address(uint(keccak256(pubKey)) & 0x000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    /**
     * @dev Calculate the Bitcoin-style address associated with an ECDSA public key
     * @param pubKey ECDSA public key to convert
     * @param isCompressed Whether or not the Bitcoin address was generated from a compressed key
     * @return Raw Bitcoin address (no base58-check encoding)
     */
    function pubKeyToBitcoinAddress(bytes pubKey, bool isCompressed) public pure returns (bytes20) {
        /* Helpful references:
           - https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses 
           - https://github.com/cryptocoinjs/ecurve/blob/master/lib/point.js
        */

        /* x coordinate - first 32 bytes of public key */
        uint x = uint(extract(pubKey, 0));
        /* y coordinate - second 32 bytes of public key */
        uint y = uint(extract(pubKey, 32)); 
        uint8 startingByte;
        if (isCompressed) {
            /* Hash the compressed public key format. */
            startingByte = y % 2 == 0 ? 0x02 : 0x03;
            return ripemd160(sha256(startingByte, x));
        } else {
            /* Hash the uncompressed public key format. */
            startingByte = 0x04;
            return ripemd160(sha256(startingByte, x, y));
        }
    }

    /**
     * @dev Verify a Merkle proof using the UTXO Merkle tree
     * @param proof Generated Merkle tree proof
     * @param merkleLeafHash Hash asserted to be present in the Merkle tree
     * @return Whether or not the proof is valid
     */
    function verifyProof(bytes32[] proof, bytes32 merkleLeafHash) public view returns (bool) {
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
    function canRedeemUTXO(bytes32 txid, bytes20 originalAddress, uint8 outputIndex, uint satoshis, bytes32[] proof) public view returns (bool) {
        /* Calculate the hash of the Merkle leaf associated with this UTXO. */
        bytes32 merkleLeafHash = keccak256(txid, originalAddress, outputIndex, satoshis);
    
        /* Verify the proof. */
        return canRedeemUTXOHash(merkleLeafHash, proof);
    }
      
    /**
     * @dev Verify that a UTXO with the specified Merkle leaf hash can be redeemed
     * @param merkleLeafHash Merkle tree hash of the UTXO to be checked
     * @param proof Merkle tree proof
     * @return Whether or not the UTXO with the specified hash can be redeemed
     */
    function canRedeemUTXOHash(bytes32 merkleLeafHash, bytes32[] proof) public view returns (bool) {
        /* Check that the UTXO has not yet been redeemed and that it exists in the Merkle tree. */
        return((redeemedUTXOs[merkleLeafHash] == false) && verifyProof(proof, merkleLeafHash));
    }

    /**
     * @dev Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address
     * @param txid Transaction hash
     * @param outputIndex Output index of the UTXO
     * @param satoshis Amount of UTXO in satoshis
     * @param proof Merkle tree proof
     * @param pubKey Uncompressed ECDSA public key to which the UTXO was sent
     * @param isCompressed Whether the Bitcoin address was generated from a compressed public key
     * @param v v parameter of ECDSA signature
     * @param r r parameter of ECDSA signature
     * @param s s parameter of ECDSA signature
     * @return The number of tokens redeemed, if successful
     */
    function redeemUTXO (bytes32 txid, uint8 outputIndex, uint satoshis, bytes32[] proof, bytes pubKey, bool isCompressed, uint8 v, bytes32 r, bytes32 s) public returns (uint tokensRedeemed) {

        /* Calculate original Bitcoin-style address associated with the provided public key. */
        bytes20 originalAddress = pubKeyToBitcoinAddress(pubKey, isCompressed);

        /* Calculate the UTXO Merkle leaf hash. */
        bytes32 merkleLeafHash = keccak256(txid, originalAddress, outputIndex, satoshis);

        /* Verify that the UTXO can be redeemed. */
        require(canRedeemUTXOHash(merkleLeafHash, proof));

        /* Claimant must sign the Ethereum address to which they wish to remit the redeemed tokens. */
        require(ecdsaVerify(msg.sender, pubKey, v, r, s));

        /* Mark the UTXO as redeemed. */
        redeemedUTXOs[merkleLeafHash] = true;

        /* Calculate the redeemed tokens. */
        tokensRedeemed = SafeMath.mul(satoshis, multiplier);

        /* Track total redeemed tokens. */
        totalRedeemed = SafeMath.add(totalRedeemed, tokensRedeemed);

        /* Sanity check. */
        require(totalRedeemed <= maximumRedeemable);

        /* Credit the redeemer. */ 
        balances[msg.sender] = SafeMath.add(balances[msg.sender], tokensRedeemed);

        /* Mark the transfer event. */
        emit Transfer(address(0), msg.sender, tokensRedeemed);

        /* Mark the UTXO redemption event. */
        emit UTXORedeemed(txid, outputIndex, satoshis, proof, pubKey, v, r, s, msg.sender, tokensRedeemed);
        
        /* Return the number of tokens redeemed. */
        return tokensRedeemed;

    }

}
