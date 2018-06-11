/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')
const WyvernProxyRegistry = artifacts.require('./WyvernProxyRegistry.sol')
const WyvernTokenTransferProxy = artifacts.require('./WyvernTokenTransferProxy.sol')
const TestToken = artifacts.require('TestToken')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'development' || network === 'rinkeby' || network === 'coverage' || network === 'main') {
    return deployer.deploy(WyvernProxyRegistry)
      .then(() => {
        setConfig('deployed.' + network + '.WyvernProxyRegistry', WyvernProxyRegistry.address)
        return TestToken.deployed().then(tokenInstance => {
          return deployer.deploy(WyvernTokenTransferProxy, WyvernProxyRegistry.address).then(() => {
            setConfig('deployed.' + network + '.WyvernTokenTransferProxy', WyvernTokenTransferProxy.address)
            return deployer.deploy(WyvernExchange, WyvernProxyRegistry.address, WyvernTokenTransferProxy.address, (network === 'development' || network === 'rinkeby' || network === 'coverage') ? tokenInstance.address : '0x056017c55ae7ae32d12aef7c679df83a85ca75ff', '0xa839d4b5a36265795eba6894651a8af3d0ae2e68')
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
  }
}
