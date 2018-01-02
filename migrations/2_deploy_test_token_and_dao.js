/* global artifacts: false */

const TestToken = artifacts.require('./TestToken.sol')
const TestDAO = artifacts.require('./TestDAO.sol')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'rinkeby' || network === 'development' || network === 'kovan') {
    deployer.deploy(TestToken)
      .then(() => {
        setConfig('deployed.' + network + '.TestToken', TestToken.address)
        return deployer.deploy(TestDAO, TestToken.address).then(() => {
          setConfig('deployed.' + network + '.TestDAO', TestDAO.address)
        })
      })
  }
}
