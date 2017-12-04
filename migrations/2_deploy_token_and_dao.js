/* global artifacts: false */

const MerkleProof = artifacts.require('./MerkleProof.sol')
const WyvernToken = artifacts.require('./WyvernToken.sol')
const WyvernDAO = artifacts.require('./WyvernDAO.sol')

const MerkleTree = require('../utxo-merkle-proof/index.js')
const fs = require('fs')
const mtStart = Date.now() / 1000
const utxoMerkleTree = MerkleTree.fromJSON(JSON.parse(fs.readFileSync('../utxo-merkle-proof/data/merkleTree.json')))
const utxoMerkleRoot = utxoMerkleTree.getHexRoot()
const mtEnd = Date.now() / 1000
console.log('Loaded UTXO merkle tree in ' + (mtEnd - mtStart) + 's - tree root: ' + utxoMerkleTree.getHexRoot())

const usStart = Date.now() / 1000
const utxoSet = JSON.parse(fs.readFileSync('../utxo-merkle-proof/data/utxos.json'))
const usEnd = Date.now() / 1000
const utxoAmount = utxoSet.reduce((x, y) => x + y.satoshis, 0)
console.log('Loaded complete UTXO set in ' + (usEnd - usStart) + 's - total UTXOs: ' + utxoSet.length + ', total amount (Satoshis): ' + utxoAmount)

module.exports = (deployer) => {
  deployer.deploy(MerkleProof)
  deployer.link(MerkleProof, WyvernToken)
  deployer.deploy(WyvernToken, utxoMerkleRoot, utxoAmount)
    .then(() => {
      deployer.deploy(WyvernDAO, WyvernToken.address, Math.pow(10, 18) * 1000000, 60 * 24 * 7)
    })
}
