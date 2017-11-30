const MerkleProof     = artifacts.require('./MerkleProof.sol');
const WyvernToken     = artifacts.require('./WyvernToken.sol');
const WyvernDAO       = artifacts.require('./WyvernDAO.sol');
const WyvernExchange  = artifacts.require('./WyvernExchange.sol');

const MerkleTree      = require('../utxo-merkle-proof/index.js');
const fs              = require('fs');
const mtStart         = Date.now() / 1000;
const utxoMerkleTree  = MerkleTree.fromJSON(JSON.parse(fs.readFileSync('../utxo-merkle-proof/data/merkleTree.json')));
const utxoMerkleRoot  = utxoMerkleTree.getHexRoot();
const mtEnd           = Date.now() / 1000;
console.log('Loaded UTXO merkle tree in ' + (mtEnd - mtStart) + 's - tree root: ' + utxoMerkleTree.getHexRoot());

module.exports = (deployer) => {
  deployer.deploy(MerkleProof);
  deployer.link(MerkleProof, WyvernToken);
  deployer.deploy(WyvernToken, utxoMerkleRoot)
    .then(() => {
      deployer.deploy(WyvernDAO, WyvernToken.address, 1, 1);
    });
  deployer.deploy(WyvernExchange);
};
