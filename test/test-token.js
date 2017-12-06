/* global artifacts:false, it:false, contract:false, assert:false */

const TestToken = artifacts.require('TestToken')

const BigNumber = require('bignumber.js')

contract('TestToken', (accounts) => {
  it('should set correct balance', () => {
    return TestToken
      .deployed()
      .then(tokenInstance => {
        return tokenInstance.balanceOf.call(accounts[0])
      })
      .then(amount => {
        assert.equal(amount.equals(new BigNumber(2 * Math.pow(10, 18 + 7))), true, 'Incorrect amount')
      })
  })
})
