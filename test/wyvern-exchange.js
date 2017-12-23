/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
const TestToken = artifacts.require('TestToken')
const DirectEscrowProvider = artifacts.require('DirectEscrowProvider')
// const BigNumber = require('bignumber.js')

contract('WyvernExchange', (accounts) => {
  it('should allow whitelisting token', () => {
    return TestToken
      .deployed()
      .then(tokenInstance => {
        return WyvernExchange
          .deployed()
          .then(exchangeInstance => {
            return exchangeInstance.modifyERC20Whitelist(tokenInstance.address, true)
              .then(() => {
                return exchangeInstance.erc20Whitelist.call(tokenInstance.address)
                  .then(ret => {
                    assert.equal(ret, true, 'Whitelist was not updated')
                  })
              })
          })
      })
  })

  it('should allow whitelisting escrow provider', () => {
    return DirectEscrowProvider
      .deployed()
      .then(escrowProviderInstance => {
        return WyvernExchange
          .deployed()
          .then(exchangeInstance => {
            return exchangeInstance.modifyEscrowProviderWhitelist(escrowProviderInstance.address, true)
              .then(() => {
                return exchangeInstance.escrowProviderWhitelist.call(escrowProviderInstance.address)
                  .then(ret => {
                    assert.equal(ret, true, 'Whitelist was not updated')
                  })
              })
          })
      })
  })
})
