/* global artifacts: false */

const WyvernExchange = artifacts.require('./WyvernExchange.sol')
const NonFungibleAssetInterface = artifacts.require('./NonFungibleAssetInterface.sol')
const SaleKindInterface = artifacts.require('./SaleKindInterface.sol')

module.exports = (deployer, network) => {
  if (network === 'development') {
    deployer.deploy(NonFungibleAssetInterface)
    deployer.link(NonFungibleAssetInterface, WyvernExchange)
    deployer.deploy(SaleKindInterface)
    deployer.link(SaleKindInterface, WyvernExchange)
    deployer.deploy(WyvernExchange)
  }
}
