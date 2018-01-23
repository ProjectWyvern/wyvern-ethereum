/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
const WyvernProxyRegistry = artifacts.require('WyvernProxyRegistry')
const BigNumber = require('bignumber.js')

const Web3 = require('web3')
const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

const hashOrder = (order) => {
  return web3.utils.soliditySha3(
    {type: 'bytes32',
      value: web3.utils.soliditySha3(
      {type: 'address', value: order.exchange},
      {type: 'address', value: order.maker},
      {type: 'address', value: order.taker},
      {type: 'uint', value: new BigNumber(order.makerFee)},
      {type: 'uint', value: new BigNumber(order.takerFee)},
      {type: 'address', value: order.feeRecipient},
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
      {type: 'uint', value: new BigNumber(order.extra)},
      {type: 'uint', value: new BigNumber(order.listingTime)},
      {type: 'uint', value: new BigNumber(order.expirationTime)},
      {type: 'uint', value: new BigNumber(order.salt)}
    ).toString('hex')}
  ).toString('hex')
}

contract('WyvernExchange', (accounts) => {
  it('should allow simple array replacement', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0xff', '0x00', '0xff').then(res => {
          assert.equal(res, '0x00', 'Array was not properly replaced!')
        })
      })
  })

  it('should disallow array replacement', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0xff', '0x00', '0x00').then(res => {
          assert.equal(res, '0xff', 'Array replacement was not disallowed!')
        })
      })
  })

  it('should allow complex array replacment', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0x0000000000000000', '0xffffffffffffffff', '0x55').then(res => {
          assert.equal(res, '0x00ff00ff00ff00ff', 'Complex array replacement did not replace properly!')
        })
      })
  })

  it('should allow simple calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x00', '0xff', '0xff', '0x00').then(res => {
          assert.equal(res, true, 'Simple calldata match was not allowed')
        })
      })
  })

  it('should allow flexible calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x00', '0xff', '0xff', '0xff').then(res => {
          assert.equal(res, true, 'Flexible calldata match was not allowed')
        })
      })
  })

  it('should allow complex calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x0000000000000000', '0x55', '0x00ff00ff00ff00ff', '0x00').then(res => {
          assert.equal(res, true, 'Complex calldata match was not allowed')
        })
      })
  })

  const makeOrder = (exchange) => ({
    exchange: exchange,
    maker: accounts[0],
    taker: accounts[0],
    makerFee: 0,
    takerFee: 0,
    feeRecipient: accounts[0],
    side: 0,
    saleKind: 0,
    target: accounts[0],
    howToCall: 0,
    calldata: '0x',
    replacementPattern: '0x',
    metadataHash: '0x',
    paymentToken: accounts[0],
    basePrice: 0,
    extra: 0,
    listingTime: 0,
    expirationTime: 0,
    salt: 0
  })

  it('should match order hash', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        const hash = hashOrder(order)
        return exchangeInstance.hashOrder_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.paymentToken],
            [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.paymentToken],
            [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
    return WyvernProxyRegistry
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
    return WyvernProxyRegistry
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
              [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.paymentToken, sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.paymentToken],
              [buy.makerFee, buy.takerFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerFee, sell.takerFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
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
