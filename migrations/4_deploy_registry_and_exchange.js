/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')
const WyvernProxyRegistry = artifacts.require('./WyvernProxyRegistry.sol')
const WyvernToken = artifacts.require('./WyvernToken.sol')
const SaleKindInterface = artifacts.require('./SaleKindInterface.sol')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'development' || network === 'rinkeby') {
    return deployer.deploy(WyvernProxyRegistry)
      .then(() => {
        setConfig('deployed.' + network + '.WyvernRegistry', WyvernProxyRegistry.address)
        return deployer.deploy(SaleKindInterface)
          .then(() => {
            setConfig('deployed.' + network + '.SaleKindInterface', SaleKindInterface.address)
            deployer.link(SaleKindInterface, WyvernExchange)
            return deployer.deploy(WyvernExchange, WyvernProxyRegistry.address, WyvernToken.address)
              .then(() => {
                setConfig('deployed.' + network + '.WyvernExchange', WyvernExchange.address)
              })
          })
      })
  }
}
