const bitcoin     = require('bitcoinjs-lib');
const web3        = require('web3');
const MerkleTree  = require('../utxo-merkle-proof/index.js');
const fs          = require('fs');
const { sha3 }    = require('ethereumjs-util');
const bs58check   = require('bs58check');

const WyvernToken     = artifacts.require('WyvernToken');
const MerkleProof     = artifacts.require('MerkleProof');

const mtStart         = Date.now() / 1000;
const utxoMerkleTree  = MerkleTree.fromJSON(JSON.parse(fs.readFileSync('utxo-merkle-proof/data/merkleTree.json')));
const utxoMerkleRoot  = utxoMerkleTree.getHexRoot();
const mtEnd           = Date.now() / 1000;
console.log('Loaded UTXO merkle tree in ' + (mtEnd - mtStart) + 's - tree root: ' + utxoMerkleTree.getHexRoot());

const usStart         = Date.now() / 1000;
const utxoSet         = JSON.parse(fs.readFileSync('utxo-merkle-proof/data/utxos.json'));
const usEnd           = Date.now() / 1000;
console.log('Loaded complete UTXO set in ' + (usEnd - usStart) + 's - total UTXOs: ' + utxoSet.length);

const hashUTXO = (utxo) => {
  const rawAddr = bs58check.decode(utxo.address).slice(0, 20).toString('hex');
  return web3.utils.soliditySha3(
    {type: 'bytes32', value: '0x' + utxo.txid},
    {type: 'bytes20', value: '0x' + rawAddr},
    {type: 'uint8', value: utxo.outputIndex},
    {type: 'uint', value: utxo.satoshis}
  );
};

contract('WyvernToken', (accounts) => {

  it('should deploy with zero tokens redeemed', () => {
    return WyvernToken
      .deployed(utxoMerkleTree.getHexRoot())
      .then(instance => {
        return instance.totalRedeemed.call();
      })
      .then(total => {
        assert.equal(0, total, 'Total was nonzero!');
      });
  });

  it('should accept valid Merkle proof', () => {
    const utxo = utxoSet[1238];
    const hash = hashUTXO(utxo);
    const proof = utxoMerkleTree.getHexProof(Buffer.from(hash.slice(2), 'hex'));

    return WyvernToken
      .deployed()
      .then(instance => {
        return instance.verifyProof.call(proof, hash);
      })
      .then(valid => {
        assert.equal(valid, true, 'Proof was not accepted');
      });
  });

  it('should reject invalid Merkle proof', () => {
    const utxo = utxoSet[11];
    const hash = hashUTXO(utxo);
    var proof = utxoMerkleTree.getHexProof(Buffer.from(hash.slice(2), 'hex'));
    proof = proof.slice(32, proof.length - 32);

    return WyvernToken
      .deployed()
      .then(instance => {
        return instance.verifyProof.call(proof, hash);
      })
      .then(valid => {
        assert.equal(valid, false, 'Proof was not rejected');
      });
  });

  it('should accept valid UTXO', () => {
    const utxo = utxoSet[1234];
    const hash = hashUTXO(utxo);
    const proof = utxoMerkleTree.getHexProof(Buffer.from(hash.slice(2), 'hex'));
    const rawAddr = bs58check.decode(utxo.address).slice(0, 20).toString('hex');
    
    return WyvernToken
      .deployed()
      .then(instance => {
        return instance.verifyUTXO('0x' + utxo.txid, '0x' + rawAddr, utxo.outputIndex, utxo.satoshis, proof);
      })
      .then(valid => {
        assert.equal(valid, true, 'UTXO was not accepted');
      });
  })

  it('should reject invalid UTXO', () => {
    const utxo = utxoSet[1234];
    const hash = hashUTXO(utxo);
    const proof = utxoMerkleTree.getHexProof(Buffer.from(hash.slice(2), 'hex'));
    const rawAddr = bs58check.decode(utxo.address).slice(0, 20).toString('hex');

    return WyvernToken
      .deployed()
      .then(instance => {
        return instance.verifyUTXO('0x' + utxo.txid, '0x' + rawAddr, utxo.outputIndex, utxo.satoshis + 1, proof);
      })
      .then(valid => {
        assert.equal(valid, false, 'UTXO was not rejected');
      });
  })

  it('should verify valid signature', () => {
    const rng = () => Buffer.from('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz');
    const keyPair = bitcoin.ECPair.makeRandom({ rng: rng, compressed: false });
    // const keyPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const address = keyPair.getAddress();
    const hashBuf = bitcoin.crypto.sha256('Test Message');
    const signature   = keyPair.sign(hashBuf);
    const compressed  = signature.toCompact(0); // This is not always true; the JS lib won't compute this. TODO FIXME
    const v = compressed.readUInt8(0);
    const r = '0x' + compressed.slice(1, 33).toString('hex');
    const s = '0x' + compressed.slice(33, 65).toString('hex');
    const hash = '0x' + hashBuf.toString('hex');
    const pubKey = '0x' + keyPair.getPublicKeyBuffer().toString('hex').slice(2);
  
    return WyvernToken
      .deployed(utxoMerkleRoot)
      .then(instance => {
        return instance.ecdsaVerify.call('Test Message', pubKey, v, r, s);
      })
      .then(valid => {
        assert.equal(valid, true, 'Signature did not validate!');
      });
  });

  it('should reject invalid signature', () => {
    const rng = () => Buffer.from('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz');
    const keyPair = bitcoin.ECPair.makeRandom({ rng: rng, compressed: false });
    // const keyPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const address = keyPair.getAddress();
    const hashBuf = bitcoin.crypto.sha256('Test Message');
    const signature   = keyPair.sign(hashBuf);
    const compressed  = signature.toCompact(0); // This is not always true; the JS lib won't compute this. TODO FIXME
    const v = compressed.readUInt8(0);
    const r = '0x' + compressed.slice(1, 33).toString('hex');
    const s = '0x' + compressed.slice(33, 65).toString('hex');
    const hash = '0x' + hashBuf.toString('hex');
    const pubKey = '0x' + keyPair.getPublicKeyBuffer().toString('hex').slice(2);
  
    return WyvernToken
      .deployed(utxoMerkleRoot)
      .then(instance => {
        return instance.ecdsaVerify.call('Test Message 2', pubKey, v, r, s);
      })
      .then(valid => {
        assert.equal(valid, false, 'Signature did not invalidate!');
      });
  });

});
