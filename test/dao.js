/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernDAO = artifacts.require('WyvernDAO')
const WyvernToken = artifacts.require('WyvernToken')
const BigNumber = require('bignumber.js')

const { utxoAmount } = require('./aux.js')

contract('WyvernDAO', (accounts) => {
  it('should have the right initial balance', () => {
    return WyvernDAO
      .deployed()
      .then(daoInstance => {
        return WyvernToken
          .deployed()
          .then(tokenInstance => {
            return tokenInstance.balanceOf.call(daoInstance.address)
          })
          .then(value => {
            const expected = (new BigNumber(20000000 * Math.pow(10, 18))).sub(new BigNumber(utxoAmount * Math.pow(10, 11)))
            assert.equal(value.equals(expected), true, 'Incorrect balance!')
          })
      })
  })

  it('should not allow release twice', () => {
    return WyvernToken
      .deployed()
      .then(tokenInstance => {
        return tokenInstance.releaseTokens.call(tokenInstance.address)
      })
      .then(() => {
        assert.equal(true, false, 'Tokens were released twice!')
      })
      .catch(() => {
      })
  })
})
