/* global artifacts: false */

const DirectEscrowProvider = artifacts.require('./DirectEscrowProvider.sol')

module.exports = (deployer, network) => {
  if (network === 'development') {
    deployer.deploy(DirectEscrowProvider)
  }
}
