/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
// const WyvernRegistry = artifacts.require('WyvernRegistry')
const TestToken = artifacts.require('TestToken')
// const BigNumber = require('bignumber.js')

// const Web3 = require('web3')
// const provider = new Web3.providers.HttpProvider('http://localhost:8545')
// const web3 = new Web3(provider)

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

  it('should allow changing public beneficiary', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.setPublicBeneficiary(exchangeInstance.address)
          .then(() => {
            return exchangeInstance.publicBeneficiary.call()
              .then(addr => {
                assert.equal(addr, exchangeInstance.address, 'Public beneficiary was not set correctly')
              })
          })
      })
  })

  it('should allow fee change', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.setFees(0, 0, 11, 11, 11, 11)
          .then(() => {
            return exchangeInstance.feeSellFrontend.call()
              .then(fee => {
                assert.equal(fee.toNumber(), 11, 'Fees were not changed correctly')
              })
          })
      })
  })

  /*
  it('should allow item purchase', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken
          .deployed()
          .then(tokenInstance => {
            return tokenInstance.approve(exchangeInstance.address, 100)
          })
        .then(() => {
          return WyvernRegistry
            .deployed()
            .then(registryInstance => {
              return registryInstance.register('account')
                .then(() => {
                  return registryInstance.proxies.call(accounts[0]).then(proxyAddr => {
                    return web3.eth.sendTransaction({from: accounts[0], to: proxyAddr, value: 1}).then(txHash => {
                    })
                  })
                })
            })
        })
        .then(() => {
          const hash = web3.utils.soliditySha3(
            {type: 'uint', value: 0},
            {type: 'address', value: accounts[0]},
            {type: 'bytes', value: '0x'},
            {type: 'uint', value: 0},
            {type: 'uint', value: 0},
            {type: 'address', value: exchangeInstance.address}
          ).toString('hex')
          return web3.eth.sign(hash, accounts[0]).then(signature => {
            signature = signature.substr(2)
            const r = '0x' + signature.slice(0, 64)
            const s = '0x' + signature.slice(64, 128)
            const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
            return exchangeInstance.purchaseItem(0, accounts[0], '0x', '0x', 0, 0, v, r, s)
              .then(() => {
              })
          })
        })
      })
  })
  */
})
