/* global artifacts: false */

const WyvernDAOProxy = artifacts.require('./WyvernDAOProxy.sol')
const WyvernExchange = artifacts.require('./WyvernExchange.sol')
const WyvernProxyRegistry = artifacts.require('./WyvernProxyRegistry.sol')
const WyvernTokenTransferProxy = artifacts.require('./WyvernTokenTransferProxy.sol')
const TestToken = artifacts.require('TestToken')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'main') {
    return deployer.deploy(WyvernExchange, '0xa4306692b00795f97010ec7237980141d08c6d56', '0x9a33a92b408b07d3be90e9828731b21a7d794af4', '0x056017c55ae7ae32d12aef7c679df83a85ca75ff', '0xa839d4b5a36265795eba6894651a8af3d0ae2e68')
      .then(() => {
        setConfig('deployed.' + network + '.WyvernExchange', WyvernExchange.address)
      })
  }
  if (network === 'development' || network === 'rinkeby' || network === 'coverage') {
    return deployer.deploy(WyvernProxyRegistry)
      .then(() => {
        setConfig('deployed.' + network + '.WyvernProxyRegistry', WyvernProxyRegistry.address)
        return TestToken.deployed().then(tokenInstance => {
          return deployer.deploy(WyvernTokenTransferProxy, WyvernProxyRegistry.address).then(() => {
            setConfig('deployed.' + network + '.WyvernTokenTransferProxy', WyvernTokenTransferProxy.address)
            return WyvernDAOProxy.deployed().then(daoProxyInstance => {
              return deployer.deploy(WyvernExchange, WyvernProxyRegistry.address, WyvernTokenTransferProxy.address, (network === 'development' || network === 'rinkeby' || network === 'coverage') ? tokenInstance.address : '0x056017c55ae7ae32d12aef7c679df83a85ca75ff', daoProxyInstance.address)
                .then(() => {
                  setConfig('deployed.' + network + '.WyvernExchange', WyvernExchange.address)
                  return WyvernProxyRegistry.deployed().then(proxyRegistry => {
                    return WyvernExchange.deployed().then(exchange => {
                      return proxyRegistry.grantInitialAuthentication(exchange.address)
                    })
                  })
                })
            })
          })
        })
      })
  }
}
