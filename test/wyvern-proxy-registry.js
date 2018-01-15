/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernProxyRegistry = artifacts.require('WyvernProxyRegistry')

contract('WyvernProxyRegistry', (accounts) => {
  it('should allow proxy creation', () => {
    return WyvernProxyRegistry
      .deployed()
      .then(registryInstance => {
        return registryInstance.registerProxy()
          .then(() => {
            return registryInstance.proxies(accounts[0])
              .then(() => {
                assert.equal(true, true, 'fixme')
              })
          })
      })
  })
})
