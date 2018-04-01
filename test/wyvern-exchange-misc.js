/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')

const arrays = [
  '0x1234',
  '0x',
  '0x123412349873',
  '0x43237234',
  '0x21982342',
  '0x112341234987323412349873',
  '0x111234123498732341234987312341234987323412349873',
  '0x111234123498732341234987312341234987323412349873219823421234',
  '0x111234123498732341234987312341234987323412349873219823421234111234123498732341234987312341234987323412349873219823421234'
]

contract('WyvernExchange', (accounts) => {
  arrays.map(arr => {
    it('should copy array ' + arr, () => {
      return WyvernExchange
        .deployed()
        .then(exchangeInstance => {
          return exchangeInstance.testCopy.call(arr).then(ret => {
            assert.equal(arr, ret, 'Copied array was unequal')
          })
        })
    })
  })

  accounts.map(acc => {
    it('should copy address ' + acc, () => {
      return WyvernExchange
        .deployed()
        .then(exchangeInstance => {
          return exchangeInstance.testCopyAddress.call(acc).then(ret => {
            assert.equal(ret, acc, 'Copied address was unequal')
          })
        })
    })
  })
})
