/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')
const WyvernRegistry = artifacts.require('./WyvernRegistry.sol')
const WyvernToken = artifacts.require('./WyvernToken.sol')
const SaleKindInterface = artifacts.require('./SaleKindInterface.sol')

const { setConfig } = require('./config.js')

module.exports = (deployer, network) => {
  if (network === 'development' || network === 'rinkeby') {
    return deployer.deploy(WyvernRegistry)
      .then(() => {
        setConfig('deployed.' + network + '.WyvernRegistry', WyvernRegistry.address)
        return deployer.deploy(SaleKindInterface)
          .then(() => {
            setConfig('deployed.' + network + '.SaleKindInterface', SaleKindInterface.address)
            deployer.link(SaleKindInterface, WyvernExchange)
            return deployer.deploy(WyvernExchange, WyvernRegistry.address, WyvernToken.address)
              .then(() => {
                setConfig('deployed.' + network + '.WyvernExchange', WyvernExchange.address)
              })
          })
      })
  }
}
