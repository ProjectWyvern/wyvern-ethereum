/* global artifacts: false */

const MerkleProof = artifacts.require('./MerkleProof.sol')
const WyvernToken = artifacts.require('./WyvernToken.sol')
const WyvernDAO = artifacts.require('./WyvernDAO.sol')

const { utxoMerkleRoot, utxoAmount } = require('../test/aux.js')

module.exports = (deployer, network) => {
  if (network === 'kovan') return
  deployer.deploy(MerkleProof)
  deployer.link(MerkleProof, WyvernToken)
  deployer.deploy(WyvernToken, utxoMerkleRoot, utxoAmount)
    .then(() => {
      return deployer.deploy(WyvernDAO, WyvernToken.address, Math.pow(10, 18) * 1000000, 60 * 24 * 7)
    })
  deployer.then(() => {
    WyvernToken.deployed()
      .then(tokenInstance => {
        return WyvernDAO.deployed()
          .then(daoInstance => {
            return tokenInstance.releaseTokens.sendTransaction(daoInstance.address)
          })
      })
  })
}
