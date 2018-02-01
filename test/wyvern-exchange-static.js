/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
const TestStatic = artifacts.require('TestStatic')

const Web3 = require('web3')
const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

contract('WyvernExchange', (accounts) => {
  it('should succeed with successful static call', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestStatic.deployed().then(staticInstance => {
          const staticTarget = staticInstance.address
          const staticInst = new web3.eth.Contract(TestStatic.abi, staticInstance.address)
          const staticExtradata = staticInst.methods.alwaysSucceed().encodeABI()
          return exchangeInstance.staticCall.call(staticTarget, '0x', staticExtradata).then(ret => {
            assert.equal(ret, true, 'Static call did not succeed')
          })
        })
      })
  })

  it('should fail with failing static call', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestStatic.deployed().then(staticInstance => {
          const staticTarget = staticInstance.address
          const staticInst = new web3.eth.Contract(TestStatic.abi, staticInstance.address)
          const staticExtradata = staticInst.methods.alwaysFail().encodeABI()
          return exchangeInstance.staticCall.call(staticTarget, '0x', staticExtradata).then(ret => {
            assert.equal(ret, false, 'Static call did not fail')
          })
        })
      })
  })
})
