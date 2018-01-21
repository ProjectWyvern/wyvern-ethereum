/* global artifacts: false */

const MerkleProof = artifacts.require('./MerkleProof.sol')
const WyvernToken = artifacts.require('./WyvernToken.sol')
const WyvernDAO = artifacts.require('./WyvernDAO.sol')

const { setConfig } = require('./config.js')
const { utxoMerkleRoot, utxoAmount } = require('../test/aux.js')

module.exports = (deployer, network) => {
  if (network === 'main' || network === 'rinkeby') return
  return deployer.deploy(MerkleProof).then(() => {
    setConfig('deployed.' + network + '.MerkleProof', MerkleProof.address)
    deployer.link(MerkleProof, WyvernToken)
    return deployer.deploy(WyvernToken, utxoMerkleRoot, utxoAmount)
      .then(() => {
        setConfig('deployed.' + network + '.WyvernToken', WyvernToken.address)
        return deployer.deploy(WyvernDAO, WyvernToken.address).then(() => {
          setConfig('deployed.' + network + '.WyvernDAO', WyvernDAO.address)
        })
      })
  }).then(() => {
    WyvernToken.deployed()
      .then(tokenInstance => {
        return WyvernDAO.deployed()
          .then(daoInstance => {
            return tokenInstance.releaseTokens.sendTransaction(daoInstance.address)
          })
      })
  })
}
