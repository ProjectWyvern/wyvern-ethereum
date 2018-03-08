/* global artifacts: false */

const TestToken = artifacts.require('./TestToken.sol')
const TestDAO = artifacts.require('./TestDAO.sol')
const TestStatic = artifacts.require('./TestStatic.sol')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'main') return
  deployer.deploy(TestToken)
    .then(() => {
      setConfig('deployed.' + network + '.TestToken', TestToken.address)
      return deployer.deploy(TestDAO, TestToken.address).then(() => {
        setConfig('deployed.' + network + '.TestDAO', TestDAO.address)
        return deployer.deploy(TestStatic).then(() => {
          setConfig('deployed.' + network + '.TestStatic', TestStatic.address)
        })
      })
    })
}
