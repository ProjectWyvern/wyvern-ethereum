/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernRegistry = artifacts.require('WyvernRegistry')

contract('WyvernRegistry', (accounts) => {
  it('should allow registration', () => {
    return WyvernRegistry
      .deployed()
      .then(registryInstance => {
        return registryInstance.register('username', registryInstance.address)
          .then(() => {
            return registryInstance.reverseUsername.call('username')
              .then(addr => {
                assert.equal(addr, accounts[0], 'Registration did not set reverseUsername')
              })
          })
      })
  })

  it('should allow username change', () => {
    return WyvernRegistry
      .deployed()
      .then(registryInstance => {
        return registryInstance.changeUsername('username2')
          .then(() => {
            return registryInstance.reverseUsername.call('username2')
              .then(addr => {
                assert.equal(addr, accounts[0], 'Username change did not set reverseUsername')
              })
          })
      })
  })
})
