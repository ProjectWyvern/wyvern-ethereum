/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')
const WyvernProxyRegistry = artifacts.require('./WyvernProxyRegistry.sol')
const SaleKindInterface = artifacts.require('./SaleKindInterface.sol')
const TestToken = artifacts.require('TestToken')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'development' || network === 'rinkeby') {
    return deployer.deploy(WyvernProxyRegistry)
      .then(() => {
        setConfig('deployed.' + network + '.WyvernProxyRegistry', WyvernProxyRegistry.address)
        return deployer.deploy(SaleKindInterface)
          .then(() => {
            setConfig('deployed.' + network + '.SaleKindInterface', SaleKindInterface.address)
            deployer.link(SaleKindInterface, WyvernExchange)
            return TestToken.deployed().then(tokenInstance => {
              return deployer.deploy(WyvernExchange, WyvernProxyRegistry.address, (network === 'development' || network === 'rinkeby') ? tokenInstance.address : '0x056017c55ae7ae32d12aef7c679df83a85ca75ff')
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
