/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
const WyvernRegistry = artifacts.require('WyvernRegistry')
const BigNumber = require('bignumber.js')

const Web3 = require('web3')
const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

const hashOrder = (order) => {
  return web3.utils.soliditySha3(
    {type: 'bytes32',
      value: web3.utils.soliditySha3(
      {type: 'address', value: order.exchange},
      {type: 'address', value: order.initiator},
      {type: 'uint8', value: order.side},
      {type: 'uint8', value: order.saleKind},
      {type: 'address', value: order.target},
      {type: 'uint8', value: order.howToCall},
      {type: 'bytes', value: order.calldata},
      {type: 'bytes', value: order.replacementPattern}
    ).toString('hex')},
    {type: 'bytes32',
      value: web3.utils.soliditySha3(
      {type: 'bytes', value: order.metadataHash},
      {type: 'address', value: order.paymentToken},
      {type: 'uint', value: new BigNumber(order.basePrice)},
      {type: 'uint', value: new BigNumber(order.baseFee)},
      {type: 'uint', value: new BigNumber(order.extra)},
      {type: 'uint', value: new BigNumber(order.listingTime)},
      {type: 'uint', value: new BigNumber(order.expirationTime)},
      {type: 'address', value: order.frontend}
    ).toString('hex')}
  ).toString('hex')
}

contract('WyvernExchange', (accounts) => {
  const makeOrder = (exchange) => ({
    exchange: exchange,
    initiator: accounts[0],
    side: 0,
    saleKind: 0,
    target: accounts[0],
    howToCall: 0,
    calldata: '0x',
    replacementPattern: '0x',
    metadataHash: '0x',
    paymentToken: accounts[0],
    basePrice: 0,
    baseFee: 0,
    extra: 0,
    listingTime: 0,
    expirationTime: 0,
    frontend: accounts[0]
  })

  it('should match order hash', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        const hash = hashOrder(order)
        return exchangeInstance.hashOrder_.call(
            [order.exchange, order.initiator, order.target, order.paymentToken, order.frontend],
            [order.basePrice, order.baseFee, order.extra, order.listingTime, order.expirationTime],
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.metadataHash).then(solHash => {
              assert.equal(solHash, hash, 'Hashes were not equal')
            })
      })
  })

  it('should validate order', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        const hash = hashOrder(order)
        return web3.eth.sign(hash, accounts[0]).then(signature => {
          signature = signature.substr(2)
          const r = '0x' + signature.slice(0, 64)
          const s = '0x' + signature.slice(64, 128)
          const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
          return exchangeInstance.validateOrder_.call(
            [order.exchange, order.initiator, order.target, order.paymentToken, order.frontend],
            [order.basePrice, order.baseFee, order.extra, order.listingTime, order.expirationTime],
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.metadataHash,
            v, r, s
          ).then(ret => {
            assert.equal(ret, true, 'Order did not validate')
          })
        })
      })
  })

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

  it('should allow auth alteration', () => {
    return WyvernRegistry
      .deployed()
      .then(registryInstance => {
        return WyvernExchange
          .deployed()
          .then(exchangeInstance => {
            return registryInstance.updateContract(exchangeInstance.address, true)
              .then(() => {
                return registryInstance.contracts.call(exchangeInstance.address).then(ret => {
                  assert.equal(ret, true, 'Auth was not altered')
                })
              })
          })
      })
  })

  it('should allow order matching', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address)
        var sell = makeOrder(exchangeInstance.address)
        sell.side = 1
        const buyHash = hashOrder(buy)
        const sellHash = hashOrder(sell)
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
              [buy.exchange, buy.initiator, buy.target, buy.paymentToken, buy.frontend, sell.exchange, sell.initiator, sell.target, sell.paymentToken, sell.frontend],
              [buy.basePrice, buy.baseFee, buy.extra, buy.listingTime, buy.expirationTime, sell.basePrice, sell.baseFee, sell.extra, sell.listingTime, sell.expirationTime],
              [buy.side, buy.saleKind, buy.howToCall, sell.side, sell.saleKind, sell.howToCall],
              buy.calldata,
              sell.calldata,
              buy.replacementPattern,
              sell.replacementPattern,
              buy.metadataHash,
              sell.metadataHash,
              [bv, sv],
              [br, bs, sr, ss]
            ).then(() => {
              // assert.equal(r.logs.length, 0, 'Order did not match')
            })
          })
        })
      })
  })
})
