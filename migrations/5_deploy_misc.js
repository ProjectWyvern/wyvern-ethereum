/* global artifacts: false */

const DirectEscrowProvider = artifacts.require('./DirectEscrowProvider.sol')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'development' || network === 'rinkeby') {
    return deployer.deploy(DirectEscrowProvider)
      .then(() => {
        setConfig('deployed.' + network + '.DirectEscrowProvider', DirectEscrowProvider.address)
      })
  }
}
