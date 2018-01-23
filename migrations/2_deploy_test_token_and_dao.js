/* global artifacts: false */

const TestToken = artifacts.require('./TestToken.sol')
const TestBank = artifacts.require('./TestBank.sol')
const TestDAO = artifacts.require('./TestDAO.sol')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'development' || network === 'kovan') {
    deployer.deploy(TestToken)
      .then(() => {
        setConfig('deployed.' + network + '.TestToken', TestToken.address)
        return deployer.deploy(TestDAO, TestToken.address).then(() => {
          setConfig('deployed.' + network + '.TestDAO', TestDAO.address)
        })
      }).then(() => {
        return deployer.deploy(TestBank).then(() => {
          setConfig('deployed.' + network + '.TestBank', TestBank.address)
        })
      })
  }
}
