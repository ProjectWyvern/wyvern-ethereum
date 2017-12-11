/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')

module.exports = (deployer, network) => {
  if (network === 'development') {
    deployer.deploy(WyvernExchange)
  }
}
