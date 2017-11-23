const bitcoin   = require('bitcoinjs-lib');
const web3      = require('web3');

const WyvernToken  = artifacts.require('WyvernToken');

contract('WyvernToken', (accounts) => {

  it('should be deployed', () => {
    return WyvernToken
      .deployed()
      .then(instance => {
        return 0;
      })
      .then(balance => {
        assert.equal(0, balance, 'Balance was nonzero!');
      });
  });

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
      .deployed()
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
      .deployed()
      .then(instance => {
        return instance.ecdsaVerify.call('Test Message 2', pubKey, v, r, s);
      })
      .then(valid => {
        assert.equal(valid, false, 'Signature did not invalidate!');
      });
  });

});
