/* global artifacts: false */

const WyvernDAOProxy = artifacts.require('./WyvernDAOProxy.sol')
const WyvernAtomicizer = artifacts.require('./WyvernAtomicizer.sol')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'main') return
  return deployer.deploy(WyvernDAOProxy)
    .then(() => {
      setConfig('deployed.' + network + '.WyvernDAOProxy', WyvernDAOProxy.address)
      return deployer.deploy(WyvernAtomicizer)
        .then(() => {
          setConfig('deployed.' + network + '.WyvernAtomicizer', WyvernAtomicizer.address)
        })
    })
}
