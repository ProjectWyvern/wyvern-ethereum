/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')
const WyvernRegistry = artifacts.require('./WyvernRegistry.sol')
const WyvernToken = artifacts.require('./WyvernToken.sol')
const NonFungibleAssetInterface = artifacts.require('./NonFungibleAssetInterface.sol')
const SaleKindInterface = artifacts.require('./SaleKindInterface.sol')

module.exports = (deployer, network) => {
  if (network === 'development') {
    return deployer.deploy(WyvernRegistry)
      .then(() => {
        return deployer.deploy(NonFungibleAssetInterface)
          .then(() => {
            deployer.link(NonFungibleAssetInterface, WyvernExchange)
            return deployer.deploy(SaleKindInterface)
              .then(() => {
                deployer.link(SaleKindInterface, WyvernExchange)
                return deployer.deploy(WyvernExchange, WyvernRegistry.address, WyvernToken.address, 0, 0, 0)
              })
          })
      })
  }
}
