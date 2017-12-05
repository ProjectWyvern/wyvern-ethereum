/* global artifacts: false */

const MerkleProof = artifacts.require('./MerkleProof.sol')
const WyvernToken = artifacts.require('./WyvernToken.sol')
const WyvernDAO = artifacts.require('./WyvernDAO.sol')

const { utxoMerkleRoot, utxoAmount } = require('../test/aux.js')

module.exports = (deployer) => {
  deployer.deploy(MerkleProof)
  deployer.link(MerkleProof, WyvernToken)
  deployer.deploy(WyvernToken, utxoMerkleRoot, utxoAmount)
    .then(() => {
      deployer.deploy(WyvernDAO, WyvernToken.address, Math.pow(10, 18) * 1000000, 60 * 24 * 7)
    })
}
