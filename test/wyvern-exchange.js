/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
const WyvernRegistry = artifacts.require('WyvernRegistry')
const TestToken = artifacts.require('TestToken')
const BigNumber = require('bignumber.js')

const Web3 = require('web3')
const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

const hashOrder = (order) => {
  return web3.utils.soliditySha3(
    {type: 'address', value: order.initiator},
    {type: 'uint8', value: order.side},
    {type: 'uint8', value: order.saleKind},
    {type: 'address', value: order.target},
    {type: 'uint8', value: order.howToCall},
    {type: 'bytes', value: order.calldata},
    {type: 'uint', value: new BigNumber(order.start)},
    {type: 'uint', value: new BigNumber(order.length)},
    {type: 'bytes', value: order.metadataHash},
    {type: 'address', value: order.paymentToken},
    {type: 'uint', value: new BigNumber(order.basePrice)},
    {type: 'uint', value: new BigNumber(order.extra)},
    // {type: 'uint', value: new BigNumber(order.listingTime)},
    {type: 'uint', value: new BigNumber(order.expirationTime)},
    {type: 'address', value: order.frontend}
  ).toString('hex')
}

contract('WyvernExchange', (accounts) => {
  const makeOrder = () => ({
    initiator: accounts[0],
    side: 0,
    saleKind: 0,
    target: accounts[0],
    howToCall: 0,
    calldata: '0x',
    start: 0,
    length: 0,
    metadataHash: '0x',
    paymentToken: accounts[0],
    basePrice: 0,
    extra: 0,
    listingTime: 0,
    expirationTime: 0,
    frontend: accounts[0]
  })

  it('should match order hash', () => {
    const order = makeOrder()
    const hash = hashOrder(order)
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.hashOrder_.call(
            [order.initiator, order.target, order.paymentToken, order.frontend],
            [order.start, order.lenth, order.basePrice, order.extra, order.listingTime, order.expirationTime],
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.metadataHash).then(solHash => {
              assert.equal(solHash, hash, 'Hashes were not equal')
            })
      })
  })

  it('should validate order', () => {
    const order = makeOrder()
    const hash = hashOrder(order)
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return web3.eth.sign(hash, accounts[0]).then(signature => {
          signature = signature.substr(2)
          const r = '0x' + signature.slice(0, 64)
          const s = '0x' + signature.slice(64, 128)
          const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
          return exchangeInstance.validateOrder_.call(
            [order.initiator, order.target, order.paymentToken, order.frontend],
            [order.start, order.lenth, order.basePrice, order.extra, order.listingTime, order.expirationTime],
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.metadataHash,
            v, r, s
          ).then(ret => {
            assert.equal(ret, true, 'Order did not validate')
          })
        })
      })
  })

  it('should allow whitelisting token', () => {
    return TestToken
      .deployed()
      .then(tokenInstance => {
        return WyvernExchange
          .deployed()
          .then(exchangeInstance => {
            // const addr = tokenInstance.address
            const addr = accounts[0]
            return exchangeInstance.modifyERC20Whitelist(addr, true)
              .then(() => {
                return exchangeInstance.erc20Whitelist.call(addr)
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
        return exchangeInstance.setFees(0, 11, 11, 11, 11)
          .then(() => {
            return exchangeInstance.feeSellFrontend.call()
              .then(fee => {
                assert.equal(fee.toNumber(), 11, 'Fees were not changed correctly')
              })
          })
      })
  })

  it('should allow proxy creation', () => {
    return WyvernRegistry
      .deployed()
      .then(registryInstance => {
        return WyvernExchange
          .deployed()
          .then(exchangeInstance => {
            return registryInstance.registerProxy(exchangeInstance.address)
              .then(() => {
                return registryInstance.proxyFor(exchangeInstance.address, accounts[0])
                  .then(() => {
                    assert.equal(true, true, 'fixme')
                  })
              })
          })
      })
  })

  it('should allow order matching', () => {
    var buy = makeOrder()
    var sell = makeOrder()
    sell.side = 1
    const buyHash = hashOrder(buy)
    const sellHash = hashOrder(sell)
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return web3.eth.sign(buyHash, accounts[0]).then(signature => {
          signature = signature.substr(2)
          const br = '0x' + signature.slice(0, 64)
          const bs = '0x' + signature.slice(64, 128)
          const bv = 27 + parseInt('0x' + signature.slice(128, 130), 16)
          return web3.eth.sign(sellHash, accounts[0]).then(signature => {
            signature = signature.substr(2)
            const sr = '0x' + signature.slice(0, 64)
            const ss = '0x' + signature.slice(64, 128)
            const sv = 27 + parseInt('0x' + signature.slice(128, 130), 16)
            return exchangeInstance.atomicMatch_(
              [buy.initiator, buy.target, buy.paymentToken, buy.frontend, sell.initiator, sell.target, sell.paymentToken, sell.frontend],
              [buy.start, buy.length, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, sell.start, sell.length, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime],
              [buy.side, sell.side],
              [buy.saleKind, sell.saleKind],
              [buy.howToCall, sell.howToCall],
              buy.calldata,
              sell.calldata,
              buy.metadataHash,
              sell.metadataHash,
              [bv, sv],
              [br, bs, sr, ss]
            ).then(r => {
              assert.equal(r.logs.length, 0, 'Order did not match')
            })
          })
        })
      })
  })
})
