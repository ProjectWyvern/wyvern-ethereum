/* global artifacts: false */

const TestToken = artifacts.require('./TestToken.sol')
const TestDAO = artifacts.require('./TestDAO.sol')

module.exports = (deployer, network) => {
  if (network === 'development' || network === 'kovan') {
    deployer.deploy(TestToken)
      .then(() => {
        return deployer.deploy(TestDAO, TestToken.address, Math.pow(10, 18) * 1000, 0)
      })
  }
}
