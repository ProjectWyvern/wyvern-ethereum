/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernAssetRegistry = artifacts.require('WyvernAssetRegistry')

contract('WyvernAssetRegistry', (accounts) => {
  it('should allow proxy creation', () => {
    return WyvernAssetRegistry
      .deployed()
      .then(registryInstance => {
      })
  })
})
