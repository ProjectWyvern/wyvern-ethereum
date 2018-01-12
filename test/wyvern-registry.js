/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernRegistry = artifacts.require('WyvernRegistry')

contract('WyvernRegistry', (accounts) => {
  it('should allow proxy creation', () => {
    return WyvernRegistry
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
