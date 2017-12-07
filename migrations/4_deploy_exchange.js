/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')

module.exports = (deployer) => {
  deployer.deploy(WyvernExchange)
}
