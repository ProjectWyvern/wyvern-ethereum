/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
const WyvernProxyRegistry = artifacts.require('WyvernProxyRegistry')
const WyvernTokenTransferProxy = artifacts.require('WyvernTokenTransferProxy')
const OwnableDelegateProxy = artifacts.require('OwnableDelegateProxy')
const TestToken = artifacts.require('TestToken')
const TestStatic = artifacts.require('TestStatic')
const AuthenticatedProxy = artifacts.require('AuthenticatedProxy')
const BigNumber = require('bignumber.js')

const Web3 = require('web3')
const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

const promisify = (inner) =>
  new Promise((resolve, reject) =>
    inner((err, res) => {
      if (err) { reject(err) }
      resolve(res)
    })
  )

var byName = {}

const traceGas = (name, res) => {
  const receipt = res.receipt
  console.log('\x1b[33m%s\x1b[0m', 'GAS', '\x1b[0m', name, ' <=> ', receipt.gasUsed)
  if (!byName[name]) {
    byName[name] = []
  }
  byName[name].push(receipt.gasUsed)
}

const finalGas = () => {
  Object.keys(byName).map(key => {
    const values = byName[key]
    const mean = values.reduce((x, y) => x + y, 0) / values.length
    console.log('\x1b[36m%s\x1b[0m', 'GAS MEAN', '\x1b[0m', key, ' <=> ', mean)
  })
}

const hashOrder = (order) => {
  return web3.utils.soliditySha3(
    {type: 'address', value: order.exchange},
    {type: 'address', value: order.maker},
    {type: 'address', value: order.taker},
    {type: 'uint', value: new BigNumber(order.makerRelayerFee)},
    {type: 'uint', value: new BigNumber(order.takerRelayerFee)},
    {type: 'uint', value: new BigNumber(order.takerProtocolFee)},
    {type: 'uint', value: new BigNumber(order.takerProtocolFee)},
    {type: 'address', value: order.feeRecipient},
    {type: 'uint8', value: order.feeMethod},
    {type: 'uint8', value: order.side},
    {type: 'uint8', value: order.saleKind},
    {type: 'address', value: order.target},
    {type: 'uint8', value: order.howToCall},
    {type: 'bytes', value: order.calldata},
    {type: 'bytes', value: order.replacementPattern},
    {type: 'address', value: order.staticTarget},
    {type: 'bytes', value: order.staticExtradata},
    {type: 'address', value: order.paymentToken},
    {type: 'uint', value: new BigNumber(order.basePrice)},
    {type: 'uint', value: new BigNumber(order.extra)},
    {type: 'uint', value: new BigNumber(order.listingTime)},
    {type: 'uint', value: new BigNumber(order.expirationTime)},
    {type: 'uint', value: order.salt}
  ).toString('hex')
}

const hashToSign = (order) => {
  const packed = web3.utils.soliditySha3(
    {type: 'address', value: order.exchange},
    {type: 'address', value: order.maker},
    {type: 'address', value: order.taker},
    {type: 'uint', value: new BigNumber(order.makerRelayerFee)},
    {type: 'uint', value: new BigNumber(order.takerRelayerFee)},
    {type: 'uint', value: new BigNumber(order.takerProtocolFee)},
    {type: 'uint', value: new BigNumber(order.takerProtocolFee)},
    {type: 'address', value: order.feeRecipient},
    {type: 'uint8', value: order.feeMethod},
    {type: 'uint8', value: order.side},
    {type: 'uint8', value: order.saleKind},
    {type: 'address', value: order.target},
    {type: 'uint8', value: order.howToCall},
    {type: 'bytes', value: order.calldata},
    {type: 'bytes', value: order.replacementPattern},
    {type: 'address', value: order.staticTarget},
    {type: 'bytes', value: order.staticExtradata},
    {type: 'address', value: order.paymentToken},
    {type: 'uint', value: new BigNumber(order.basePrice)},
    {type: 'uint', value: new BigNumber(order.extra)},
    {type: 'uint', value: new BigNumber(order.listingTime)},
    {type: 'uint', value: new BigNumber(order.expirationTime)},
    {type: 'uint', value: order.salt}
  ).toString('hex')
  return web3.utils.soliditySha3(
    {type: 'string', value: '\x19Ethereum Signed Message:\n32'},
    {type: 'bytes32', value: packed}
  ).toString('hex')
}

contract('WyvernExchange', (accounts) => {
  it('should allow simple array replacement', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0xff', '0x00', '0xff').then(res => {
          assert.equal(res, '0x00', 'Array was not properly replaced!')
          return exchangeInstance.guardedArrayReplace.estimateGas('0xff', '0x00', '0xff').then(gas => {
            traceGas('guardedArrayReplace', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  it('should disallow array replacement', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0xff', '0x00', '0x00').then(res => {
          assert.equal(res, '0xff', 'Array replacement was not disallowed!')
          return exchangeInstance.guardedArrayReplace.estimateGas('0xff', '0x00', '0x00').then(gas => {
            traceGas('guardedArrayReplace', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  it('should allow complex array replacment', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0x0000000000000000', '0xffffffffffffffff', '0x00ff00ff00ff00ff').then(res => {
          assert.equal(res, '0x00ff00ff00ff00ff', 'Complex array replacement did not replace properly!')
          return exchangeInstance.guardedArrayReplace.estimateGas('0x0000000000000000', '0xffffffffffffffff', '0x00ff00ff00ff00ff').then(gas => {
            traceGas('guardedArrayReplace', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  it('should allow trivial array replacement', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0x00', '0x11', '0xff').then(res => {
          assert.equal(res, '0x11')
        })
      })
  })

  it('should allow trivial array replacement 2', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0xff', '0x00', '0xff').then(res => {
          assert.equal(res, '0x00')
        })
      })
  })

  it('should allow basic array replacement A', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call(
          '0x23b872dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065abe5f01cf94d37762780695cf19b151ed5809000000000000000000000000000000000000000000000000000000000000006f',
          '0x23b872dd000000000000000000000000431e44389a003f0ec6e83b3578db5075a44ac5230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006f',
          '0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000').then(res => {
            assert.equal('0x23b872dd000000000000000000000000431e44389a003f0ec6e83b3578db5075a44ac523000000000000000000000000065abe5f01cf94d37762780695cf19b151ed5809000000000000000000000000000000000000000000000000000000000000006f', res, 'testing A')
          })
      })
  })

  it('should allow basic array replacement B', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call(
          '0x23b872dd000000000000000000000000431e44389a003f0ec6e83b3578db5075a44ac5230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006f',
          '0x23b872dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065abe5f01cf94d37762780695cf19b151ed5809000000000000000000000000000000000000000000000000000000000000006f',
          '0x000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000').then(res => {
            assert.equal('0x23b872dd000000000000000000000000431e44389a003f0ec6e83b3578db5075a44ac523000000000000000000000000065abe5f01cf94d37762780695cf19b151ed5809000000000000000000000000000000000000000000000000000000000000006f', res, 'testing B')
          })
      })
  })

  it('should allow basic array replacement C', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call(
          '0xff23b872dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065abe5f01cf94d37762780695cf19b151ed5809000000000000000000000000000000000000000000000000000000000000006fff',
          '0x0023b872dd000000000000000000000000431e44389a003f0ec6e83b3578db5075a44ac5230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006f00',
          '0xff00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff').then(res => {
            assert.equal('0x0023b872dd000000000000000000000000431e44389a003f0ec6e83b3578db5075a44ac523000000000000000000000000065abe5f01cf94d37762780695cf19b151ed5809000000000000000000000000000000000000000000000000000000000000006f00', res, 'testing C')
          })
      })
  })

  it('should allow large complex array replacment', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.guardedArrayReplace.call('0x0000000000000000000000000000000000000000000000000000000000000000', '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', '0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff').then(res => {
          assert.equal(res, '0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff', 'Complex array replacement did not replace properly!')
          return exchangeInstance.guardedArrayReplace.estimateGas('0x0000000000000000000000000000000000000000000000000000000000000000', '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', '0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff').then(gas => {
            traceGas('guardedArrayReplace', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  return

  it('should allow simple calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x00', '0xff', '0xff', '0x00').then(res => {
          assert.equal(res, true, 'Simple calldata match was not allowed')
          return exchangeInstance.orderCalldataCanMatch.estimateGas('0x00', '0xff', '0xff', '0x00').then(gas => {
            traceGas('orderCalldataCanMatch', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  it('should allow flexible calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x00', '0xff', '0xff', '0xff').then(res => {
          assert.equal(res, true, 'Flexible calldata match was not allowed')
          return exchangeInstance.orderCalldataCanMatch.estimateGas('0x00', '0xff', '0xff', '0xff').then(gas => {
            traceGas('orderCalldataCanMatch', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  it('should allow complex calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x0000000000000000', '0x00ff00ff00ff00ff', '0x00ff00ff00ff00ff', '0x0000000000000000').then(res => {
          assert.equal(res, true, 'Complex calldata match was not allowed')
          return exchangeInstance.orderCalldataCanMatch.estimateGas('0x0000000000000000', '0x00ff00ff00ff00ff', '0x00ff00ff00ff00ff', '0x0000000000000000').then(gas => {
            traceGas('orderCalldataCanMatch', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  it('should allow complex large calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x0000000000000000000000000000000000000000000000000000000000000000', '0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff', '0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff', '0x0000000000000000000000000000000000000000000000000000000000000000').then(res => {
          assert.equal(res, true, 'Complex calldata match was not allowed')
          return exchangeInstance.orderCalldataCanMatch.estimateGas('0x0000000000000000000000000000000000000000000000000000000000000000', '0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff', '0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff', '0x0000000000000000000000000000000000000000000000000000000000000000').then(gas => {
            traceGas('orderCalldataCanMatch', {receipt: { gasUsed: gas }})
          })
        })
      })
  })

  it('should disallow false complex calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x0000000000000000', '0x0000000000000000', '0x00ff00ff00ff00ff', '0x0000000000000000').then(res => {
          assert.equal(res, false, 'Complex calldata match was not allowed')
        })
      })
  })

  it('should revert on different bytecode size', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x0000000000000000', '0x0000000000000000', '0x00ff00ff00ff00', '0x0000000000000000').then(() => {
          assert.equal(true, false, 'Did not revert on different bytecode size')
        }).catch(err => {
          assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
        })
      })
  })

  it('should revert on insufficient replacementPattern size', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x00000000000000000000000000000000', '0x00', '0x00ff00ff00ff00ff0000000000000000', '0x00').then(() => {
          assert.equal(true, false, 'Did not revert on insufficient replacementPattern size')
        }).catch(err => {
          assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
        })
      })
  })

  it('should allow changing minimum maker protocol fee', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.changeMinimumMakerProtocolFee(1).then(res => {
          traceGas('changeMinimumMakerProtocolFee', res)
          return exchangeInstance.minimumMakerProtocolFee.call().then(res => {
            assert.equal(res.toNumber(), 1, 'Protocol fee was not changed')
            return exchangeInstance.changeMinimumMakerProtocolFee(0)
          })
        })
      })
  })

  it('should allow changing minimum taker protocol fee', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.changeMinimumTakerProtocolFee(1).then(res => {
          traceGas('changeMinimumTakerProtocolFee', res)
          return exchangeInstance.minimumTakerProtocolFee.call().then(res => {
            assert.equal(res.toNumber(), 1, 'Protocol fee was not changed')
            return exchangeInstance.changeMinimumTakerProtocolFee(0)
          })
        })
      })
  })

  it('should allow changing protocol fee recipient', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.changeProtocolFeeRecipient(accounts[1]).then(res => {
          traceGas('changeProtocolFeeRecipient', res)
          return exchangeInstance.protocolFeeRecipient.call().then(res => {
            assert.equal(res, accounts[1], 'Protocol fee recipient was not changed')
            return exchangeInstance.changeProtocolFeeRecipient(accounts[0])
          })
        })
      })
  })

  var proxy

  it('should allow proxy creation', () => {
    return WyvernProxyRegistry
      .deployed()
      .then(registryInstance => {
        return registryInstance.registerProxy()
          .then(res => {
            traceGas('registerProxy', res)
            return registryInstance.proxies(accounts[0])
              .then(prx => {
                proxy = prx
                assert.equal(true, true, 'fixme')
              })
          })
      })
  })

  const makeOrder = (exchange, isMaker) => ({
    exchange: exchange,
    maker: accounts[0],
    taker: accounts[0],
    makerRelayerFee: 0,
    takerRelayerFee: 0,
    makerProtocolFee: 0,
    takerProtocolFee: 0,
    feeRecipient: isMaker ? accounts[0] : '0x0000000000000000000000000000000000000000',
    feeMethod: 0,
    side: 0,
    saleKind: 0,
    target: proxy,
    howToCall: 0,
    calldata: '0x',
    replacementPattern: '0x',
    staticTarget: '0x0000000000000000000000000000000000000000',
    staticExtradata: '0x',
    paymentToken: accounts[0],
    basePrice: new BigNumber(0),
    extra: 0,
    listingTime: 0,
    expirationTime: 0,
    salt: new BigNumber(0)
  })

  it('should match order hash', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        const hash = hashOrder(order)
        return exchangeInstance.hashOrder_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
            order.feeMethod,
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.staticExtradata).then(solHash => {
              assert.equal(solHash, hash, 'Hashes were not equal')
            })
      })
  })

  it('should match order hash to sign', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        const hash = hashToSign(order)
        return exchangeInstance.hashToSign_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
            order.feeMethod,
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.staticExtradata).then(solHash => {
              assert.equal(solHash, hash, 'Hashes were not equal')
            })
      })
  })

  it('should validate order', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address, true)
        order.saleKind = 0
        order.listingTime = 1
        order.expirationTime = 1000
        const hash = hashOrder(order)
        return web3.eth.sign(hash, accounts[0]).then(() => {
          return exchangeInstance.validateOrderParameters_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
            order.feeMethod,
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.staticExtradata
          ).then(ret => {
            assert.equal(ret, true, 'Order did not validate')
            return exchangeInstance.calculateCurrentPrice_.call(
              [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
              [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
              order.feeMethod,
              order.side,
              order.saleKind,
              order.howToCall,
              order.calldata,
              order.replacementPattern,
              order.staticExtradata).then(price => {
                assert.equal(price.toNumber(), 0, 'Incorrect price')
              })
          })
        })
      })
  })

  it('should not validate order with invalid saleKind / expiration', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        order.saleKind = 1
        const hash = hashOrder(order)
        return web3.eth.sign(hash, accounts[0]).then(signature => {
          signature = signature.substr(2)
          const r = '0x' + signature.slice(0, 64)
          const s = '0x' + signature.slice(64, 128)
          const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
          return exchangeInstance.validateOrder_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
            order.feeMethod,
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.staticExtradata,
            v, r, s
          ).then(ret => {
            assert.equal(ret, false, 'Order with invalid parameters validated')
          })
        })
      })
  })

  it('should not validate order with invalid exchange', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        order.exchange = accounts[0]
        const hash = hashOrder(order)
        return web3.eth.sign(hash, accounts[0]).then(signature => {
          signature = signature.substr(2)
          const r = '0x' + signature.slice(0, 64)
          const s = '0x' + signature.slice(64, 128)
          const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
          return exchangeInstance.validateOrder_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
            order.feeMethod,
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.staticExtradata,
            v, r, s
          ).then(ret => {
            assert.equal(ret, false, 'Order with invalid parameters validated')
          })
        })
      })
  })

  it('should not validate order with invalid maker protocol fees', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.changeMinimumMakerProtocolFee(1).then(() => {
          const order = makeOrder(exchangeInstance.address)
          order.feeMethod = 1
          order.salt = 213898123
          const hash = hashOrder(order)
          return web3.eth.sign(hash, accounts[0]).then(signature => {
            signature = signature.substr(2)
            const r = '0x' + signature.slice(0, 64)
            const s = '0x' + signature.slice(64, 128)
            const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
            return exchangeInstance.validateOrder_.call(
              [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
              [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
              order.feeMethod,
              order.side,
              order.saleKind,
              order.howToCall,
              order.calldata,
              order.replacementPattern,
              order.staticExtradata,
              v, r, s
            ).then(ret => {
              assert.equal(ret, false, 'Order with invalid parameters validated')
              return exchangeInstance.changeMinimumMakerProtocolFee(0)
            })
          })
        })
      })
  })

  it('should not validate order with invalid taker protocol fees', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.changeMinimumTakerProtocolFee(1).then(() => {
          const order = makeOrder(exchangeInstance.address)
          order.feeMethod = 1
          order.salt = 21389812323
          const hash = hashOrder(order)
          return web3.eth.sign(hash, accounts[0]).then(signature => {
            signature = signature.substr(2)
            const r = '0x' + signature.slice(0, 64)
            const s = '0x' + signature.slice(64, 128)
            const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
            return exchangeInstance.validateOrder_.call(
              [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
              [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
              order.feeMethod,
              order.side,
              order.saleKind,
              order.howToCall,
              order.calldata,
              order.replacementPattern,
              order.staticExtradata,
              v, r, s
            ).then(ret => {
              assert.equal(ret, false, 'Order with invalid parameters validated')
              return exchangeInstance.changeMinimumTakerProtocolFee(0)
            })
          })
        })
      })
  })

  const getTime = (cb) => {
    web3.eth.getBlockNumber((err, num) => {
      if (err) throw err
      web3.eth.getBlock(num, (err, block) => {
        if (err) throw err
        cb(null, block.timestamp)
      })
    })
  }

  it('should have correct prices for dutch auctions', () => {
    return WyvernExchange
      .deployed()
      .then(async exchangeInstance => {
        const time = await promisify(getTime)
        return exchangeInstance.calculateFinalPrice.call(1, 1, 100, 100, time, time + 100).then(async price => {
          assert.equal(price.toNumber(), 100, 'Incorrect price')
          const time = await promisify(getTime)
          return exchangeInstance.calculateFinalPrice.call(1, 1, 100, 100, time - 100, time).then(async price => {
            assert.equal(price.toNumber(), 0, 'Incorrect price')
            const time = await promisify(getTime)
            return exchangeInstance.calculateFinalPrice.call(0, 1, 100, 100, time - 50, time + 50).then(async price => {
              assert.equal(price.toNumber(), 150, 'Incorrect price')
              const time = await promisify(getTime)
              return exchangeInstance.calculateFinalPrice.call(0, 1, 100, 200, time - 50, time + 50).then(price => {
                assert.equal(price.toNumber(), 200, 'Incorrect price')
              })
            })
          })
        })
      })
  })

  it('should not validate order from different address', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        return exchangeInstance.validateOrder_.call(
          [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
          [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
          order.feeMethod,
          order.side,
          order.saleKind,
          order.howToCall,
          order.calldata,
          order.replacementPattern,
          order.staticExtradata,
          0, '0x', '0x',
          {from: accounts[1]}
        ).then(ret => {
          assert.equal(ret, false, 'Order was validated from different address')
        })
      })
  })

  it('should not allow order approval from different address', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        return exchangeInstance.approveOrder_(
          [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
          [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
          order.feeMethod,
          order.side,
          order.saleKind,
          order.howToCall,
          order.calldata,
          order.replacementPattern,
          order.staticExtradata,
          true,
          {from: accounts[1]}
          ).then(() => {
            assert.equal(true, false, 'Order approval was allowed from different address')
          }).catch(err => {
            assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
          })
      })
  })

  it('should allow order approval, then cancellation', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const order = makeOrder(exchangeInstance.address)
        return exchangeInstance.hashOrder_.estimateGas(
          [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
          [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
          order.feeMethod,
          order.side,
          order.saleKind,
          order.howToCall,
          order.calldata,
          order.replacementPattern,
          order.staticExtradata).then(gas => {
            traceGas('hashOrder_', { receipt: { gasUsed: gas } })
            return exchangeInstance.approveOrder_(
              [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
              [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
              order.feeMethod,
              order.side,
              order.saleKind,
              order.howToCall,
              order.calldata,
              order.replacementPattern,
              order.staticExtradata,
              true
            ).then(res => {
              traceGas('approveOrder_', res)
              return exchangeInstance.validateOrder_.call(
                [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
                [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
                order.feeMethod,
                order.side,
                order.saleKind,
                order.howToCall,
                order.calldata,
                order.replacementPattern,
                order.staticExtradata,
                0, '0x', '0x',
                {from: accounts[1]}
              ).then(ret => {
                assert.equal(ret, true, 'Order did not validate')
                return exchangeInstance.cancelOrder_(
                  [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
                  [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
                  order.feeMethod,
                  order.side,
                  order.saleKind,
                  order.howToCall,
                  order.calldata,
                  order.replacementPattern,
                  order.staticExtradata,
                  0, '0x', '0x'
                ).then(res => {
                  traceGas('cancelOrder_', res)
                  return exchangeInstance.validateOrder_.call(
                    [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
                    [order.makerRelayerFee, order.takerRelayerFee, order.makerProtocolFee, order.takerProtocolFee, order.basePrice, order.extra, order.listingTime, order.expirationTime, order.salt],
                    order.feeMethod,
                    order.side,
                    order.saleKind,
                    order.howToCall,
                    order.calldata,
                    order.replacementPattern,
                    order.staticExtradata,
                    0, '0x', '0x'
                  ).then(ret => {
                    assert.equal(ret, false, 'Order did not validate')
                  })
                })
              })
            })
          })
      })
  })

  it('should have correct auth', () => {
    return WyvernProxyRegistry
      .deployed()
      .then(registryInstance => {
        return WyvernExchange
          .deployed().then(exchangeInstance => {
            return registryInstance.contracts.call(exchangeInstance.address).then(ret => {
              assert.equal(ret, true, 'Proxy registry did not have Exchange authenticated!')
            })
          })
      })
  })

  const matchOrder = (buy, sell, thenFunc, catchFunc, value) => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        const buyHash = hashOrder(buy)
        const sellHash = hashOrder(sell)
        return web3.eth.sign(buyHash, accounts[0]).then(signature => {
          signature = signature.substr(2)
          const br = '0x' + signature.slice(0, 64)
          const bs = '0x' + signature.slice(64, 128)
          const bv = 27 + parseInt('0x' + signature.slice(128, 130), 16)
          return web3.eth.sign(sellHash, accounts[0]).then(async signature => {
            signature = signature.substr(2)
            const sr = '0x' + signature.slice(0, 64)
            const ss = '0x' + signature.slice(64, 128)
            const sv = 27 + parseInt('0x' + signature.slice(128, 130), 16)
            await exchangeInstance.hashOrder_.estimateGas(
              [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken],
              [buy.makerRelayerFee, buy.takerRelayerFee, buy.makerProtocolFee, buy.takerProtocolFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt],
              buy.feeMethod,
              buy.side,
              buy.saleKind,
              buy.howToCall,
              buy.calldata,
              buy.replacementPattern,
              buy.staticExtradata).then(gas => {
                traceGas('hashOrder_', { receipt: { gasUsed: gas } })
              })
            await exchangeInstance.hashOrder_.estimateGas(
              [sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
              [sell.makerRelayerFee, sell.takerRelayerFee, sell.makerProtocolFee, sell.takerProtocolFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
              sell.feeMethod,
              sell.side,
              sell.saleKind,
              sell.howToCall,
              sell.calldata,
              sell.replacementPattern,
              sell.staticExtradata).then(gas => {
                traceGas('hashOrder_', { receipt: { gasUsed: gas } })
              })
            return exchangeInstance.ordersCanMatch_.call(
              [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken, sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
              [buy.makerRelayerFee, buy.takerRelayerFee, buy.makerProtocolFee, buy.takerProtocolFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerRelayerFee, sell.takerRelayerFee, sell.makerProtocolFee, sell.takerProtocolFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
              [buy.feeMethod, buy.side, buy.saleKind, buy.howToCall, sell.feeMethod, sell.side, sell.saleKind, sell.howToCall],
              buy.calldata,
              sell.calldata,
              buy.replacementPattern,
              sell.replacementPattern,
              buy.staticExtradata,
              sell.staticExtradata
            ).then(ret => {
              assert.equal(ret, true, 'Orders were not matchable!')
              return exchangeInstance.calculateMatchPrice_.call(
                [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken, sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
                [buy.makerRelayerFee, buy.takerRelayerFee, buy.makerProtocolFee, buy.takerProtocolFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerRelayerFee, sell.takerRelayerFee, sell.makerProtocolFee, sell.takerProtocolFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
                [buy.feeMethod, buy.side, buy.saleKind, buy.howToCall, sell.feeMethod, sell.side, sell.saleKind, sell.howToCall],
                buy.calldata,
                sell.calldata,
                buy.replacementPattern,
                sell.replacementPattern,
                buy.staticExtradata,
                sell.staticExtradata
              ).then(matchPrice => {
                assert.equal(matchPrice.toNumber(), buy.basePrice.toNumber(), 'Incorrect match price!')
                return exchangeInstance.approveOrder_(
                  [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken],
                  [buy.makerRelayerFee, buy.takerRelayerFee, buy.makerProtocolFee, buy.takerProtocolFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt],
                  buy.feeMethod,
                  buy.side,
                  buy.saleKind,
                  buy.howToCall,
                  buy.calldata,
                  buy.replacementPattern,
                  buy.staticExtradata,
                  true
                ).then(res => {
                  traceGas('approveOrder_', res)
                  return exchangeInstance.approveOrder_(
                    [sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
                    [sell.makerRelayerFee, sell.takerRelayerFee, sell.makerProtocolFee, sell.takerProtocolFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
                    sell.feeMethod,
                    sell.side,
                    sell.saleKind,
                    sell.howToCall,
                    sell.calldata,
                    sell.replacementPattern,
                    sell.staticExtradata,
                    true
                  ).then(res => {
                    traceGas('approveOrder_', res)
                    return exchangeInstance.atomicMatch_(
                      [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken, sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
                      [buy.makerRelayerFee, buy.takerRelayerFee, buy.makerProtocolFee, buy.takerProtocolFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerRelayerFee, sell.takerRelayerFee, sell.makerProtocolFee, sell.takerProtocolFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
                      [buy.feeMethod, buy.side, buy.saleKind, buy.howToCall, sell.feeMethod, sell.side, sell.saleKind, sell.howToCall],
                      buy.calldata,
                      sell.calldata,
                      buy.replacementPattern,
                      sell.replacementPattern,
                      buy.staticExtradata,
                      sell.staticExtradata,
                      [bv, sv],
                      [br, bs, sr, ss, '0x0000000000000000000000000000000000000000000000000000000000000000'], {from: value ? accounts[0] : accounts[1], value: value || 0}).then(res => {
                        traceGas('atomicMatch_', res)
                        return thenFunc()
                      })
                  })
                })
              })
            })
          })
        })
      }).catch(catchFunc)
  }

  it('should allow approval', () => {
    return WyvernTokenTransferProxy
      .deployed()
      .then(tokenTransferProxyInstance => {
        return TestToken
          .deployed()
          .then(tokenInstance => {
            return tokenInstance.approve(tokenTransferProxyInstance.address, 10000000000)
          })
      })
  })

  it('should allow simple order matching', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        })
      })
  })

  it('should not allow match with mismatched calldata', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.calldata = '0x00ff00ff'
        buy.replacementPattern = '0x00000000'
        sell.calldata = '0xff00ff00'
        sell.replacementPattern = '0x00ff00ff'
        return matchOrder(buy, sell, () => {
          assert.equal(false, true, 'Orders should not have matched')
        }, err => {
          assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
        })
      })
  })

  it('should not allow match with mismatched calldata, flipped sides', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        sell.calldata = '0x00ff00ff'
        sell.replacementPattern = '0x00000000'
        buy.calldata = '0xff00ff00'
        buy.replacementPattern = '0x00ff00ff'
        return matchOrder(buy, sell, () => {
          assert.equal(false, true, 'Orders should not have matched')
        }, err => {
          assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
        })
      })
  })

  it('should allow simple order matching with special-case Ether', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.paymentToken = '0x0000000000000000000000000000000000000000'
        sell.paymentToken = '0x0000000000000000000000000000000000000000'
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        })
      })
  })

  it('should allow simple order matching with special-case Ether, nonzero price', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.paymentToken = '0x0000000000000000000000000000000000000000'
        sell.paymentToken = '0x0000000000000000000000000000000000000000'
        buy.basePrice = new BigNumber(100)
        sell.basePrice = new BigNumber(100)
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        }, 100)
      })
  })

  it('should allow simple order matching with special-case Ether, nonzero fees, new fee method', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, false)
        var sell = makeOrder(exchangeInstance.address, true)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.paymentToken = '0x0000000000000000000000000000000000000000'
        sell.paymentToken = '0x0000000000000000000000000000000000000000'
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        sell.makerProtocolFee = new BigNumber(100)
        sell.makerRelayerFee = new BigNumber(100)
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        }, 10000)
      })
  })

  it('should allow simple order matching with special-case Ether, nonzero fees, new fee method, taker', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, false)
        var sell = makeOrder(exchangeInstance.address, true)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.paymentToken = '0x0000000000000000000000000000000000000000'
        sell.paymentToken = '0x0000000000000000000000000000000000000000'
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        sell.takerProtocolFee = new BigNumber(100)
        sell.takerRelayerFee = new BigNumber(100)
        buy.takerProtocolFee = new BigNumber(100)
        buy.takerRelayerFee = new BigNumber(100)
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        }, 10200)
      })
  })

  it('should allow simple order matching with special-case Ether, nonzero fees, new fee method, both maker / taker', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, false)
        var sell = makeOrder(exchangeInstance.address, true)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.salt = 40
        buy.paymentToken = '0x0000000000000000000000000000000000000000'
        sell.paymentToken = '0x0000000000000000000000000000000000000000'
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        sell.makerProtocolFee = new BigNumber(100)
        sell.makerRelayerFee = new BigNumber(100)
        sell.takerProtocolFee = new BigNumber(100)
        sell.takerRelayerFee = new BigNumber(100)
        buy.takerProtocolFee = new BigNumber(100)
        buy.takerRelayerFee = new BigNumber(100)
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        }, 10200)
      })
  })

  it('should allow simple order matching with special-case Ether, nonzero price, overpayment', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.paymentToken = '0x0000000000000000000000000000000000000000'
        sell.paymentToken = '0x0000000000000000000000000000000000000000'
        buy.basePrice = new BigNumber(101)
        sell.basePrice = new BigNumber(101)
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        }, 105)
      })
  })

  it('should not allow simple order matching with special-case Ether, nonzero price, wrong value', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.paymentToken = '0x0000000000000000000000000000000000000000'
        sell.paymentToken = '0x0000000000000000000000000000000000000000'
        buy.basePrice = new BigNumber(100)
        sell.basePrice = new BigNumber(100)
        return matchOrder(buy, sell, () => {
          assert.equal(false, true, 'Orders should not have matched')
        }, err => {
          assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
        }, 10)
      })
  })

  it('should allow simple order matching, second fee method', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        return TestToken.deployed().then(tokenInstance => {
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should allow simple order matching, second fee method, nonzero price', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        buy.salt = 5123
        sell.salt = 12389
        return TestToken.deployed().then(tokenInstance => {
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should allow simple order matching, second fee method, real taker relayer fees', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        sell.takerRelayerFee = new BigNumber(100)
        buy.takerRelayerFee = new BigNumber(100)
        return TestToken.deployed().then(tokenInstance => {
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should allow simple order matching, second fee method, real taker protocol fees', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.basePrice = new BigNumber(10)
        sell.basePrice = new BigNumber(10)
        sell.takerProtocolFee = new BigNumber(100)
        buy.takerProtocolFee = new BigNumber(100)
        return TestToken.deployed().then(tokenInstance => {
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should allow simple order matching, second fee method, real maker protocol fees', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        sell.makerProtocolFee = new BigNumber(100)
        buy.makerProtocolFee = new BigNumber(100)
        return TestToken.deployed().then(tokenInstance => {
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should allow simple order matching, second fee method, all fees', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        sell.makerProtocolFee = new BigNumber(100)
        buy.makerProtocolFee = new BigNumber(100)
        sell.makerRelayerFee = new BigNumber(100)
        buy.makerRelayerFee = new BigNumber(100)
        sell.takerProtocolFee = new BigNumber(100)
        buy.takerProtocolFee = new BigNumber(100)
        sell.takerRelayerFee = new BigNumber(100)
        buy.takerRelayerFee = new BigNumber(100)
        return TestToken.deployed().then(tokenInstance => {
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should allow simple order matching, second fee method, all fees, swapped maker/taker', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, false)
        var sell = makeOrder(exchangeInstance.address, true)
        sell.side = 1
        buy.feeMethod = 1
        sell.feeMethod = 1
        buy.basePrice = new BigNumber(10000)
        sell.basePrice = new BigNumber(10000)
        sell.makerProtocolFee = new BigNumber(100)
        buy.makerProtocolFee = new BigNumber(100)
        sell.makerRelayerFee = new BigNumber(100)
        buy.makerRelayerFee = new BigNumber(100)
        sell.takerProtocolFee = new BigNumber(100)
        buy.takerProtocolFee = new BigNumber(100)
        sell.takerRelayerFee = new BigNumber(100)
        buy.takerRelayerFee = new BigNumber(100)
        return TestToken.deployed().then(tokenInstance => {
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should not allow order matching twice', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed twice')
        }, err => {
          assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
        })
      })
  })

  it('should not allow order match if proxy changes', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.salt = 123981
        sell.salt = 12381980
        return WyvernProxyRegistry
          .deployed()
          .then(registryInstance => {
            return registryInstance.proxies(accounts[0])
              .then(ret => {
                const contract = new web3.eth.Contract(OwnableDelegateProxy.abi, ret)
                return contract.methods.upgradeTo(registryInstance.address).send({from: accounts[0]}).then(() => {
                  return matchOrder(buy, sell, () => {
                    assert.equal(true, false, 'Matching was allowed with different proxy')
                  }, err => {
                    assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
                    return registryInstance.delegateProxyImplementation().then(impl => {
                      return contract.methods.upgradeTo(impl).send({from: accounts[0]}).then(() => {
                      })
                    })
                  })
                })
              })
          })
      })
  })

  it('should not allow proxy reentrancy', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        sell.target = exchangeInstance.address
        buy.target = exchangeInstance.address
        const contract = new web3.eth.Contract(WyvernExchange.abi, exchangeInstance.address)
        const calldata = contract.methods.atomicMatch_(
          [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken, sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
          [buy.makerRelayerFee, buy.takerRelayerFee, buy.makerProtocolFee, buy.takerProtocolFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerRelayerFee, sell.takerRelayerFee, sell.makerProtocolFee, sell.takerProtocolFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
          [buy.feeMethod, buy.side, buy.saleKind, buy.howToCall, sell.feeMethod, sell.side, sell.saleKind, sell.howToCall],
          buy.calldata,
          sell.calldata,
          buy.replacementPattern,
          sell.replacementPattern,
          buy.staticExtradata,
          sell.staticExtradata,
          [0, 0],
          ['0x', '0x', '0x', '0x', '0x0000000000000000000000000000000000000000000000000000000000000000']
        ).encodeABI()
        sell.calldata = calldata
        buy.calldata = calldata
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching proxy reentrancy was allowed')
        }, err => {
          assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
        })
      })
  })

  it('should fail with same side', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed with same side')
        }, err => {
          assert.equal(err.message, 'Orders were not matchable!: expected false to equal true', 'Incorrect error')
        })
      })
  })

  it('should fail with different payment token', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.paymentToken = accounts[1]
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed with different payment token')
        }, err => {
          assert.equal(err.message, 'Orders were not matchable!: expected false to equal true', 'Incorrect error')
        })
      })
  })

  it('should fail with wrong maker/taker', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.taker = accounts[1]
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed with non-matching maker/taker')
        }, err => {
          assert.equal(err.message, 'Orders were not matchable!: expected false to equal true', 'Incorrect error')
        })
      })
  })

  it('should succeed with zero-address taker', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.salt = 32
        sell.salt = 23
        buy.taker = '0x0000000000000000000000000000000000000000'
        return matchOrder(buy, sell, () => {}, err => {
          assert.equal(false, err, 'Orders should have matched')
        })
      })
  })

  it('should fail with different target', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.target = accounts[1]
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed with non-identical target')
        }, err => {
          assert.equal(err.message, 'Orders were not matchable!: expected false to equal true', 'Incorrect error')
        })
      })
  })

  it('should fail with different howToCall', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.howToCall = 1
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed with non-identical target')
        }, err => {
          assert.equal(err.message, 'Orders were not matchable!: expected false to equal true', 'Incorrect error')
        })
      })
  })

  it('should fail with listing time past now', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.listingTime = new BigNumber(Math.pow(10, 10))
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed with listing time past now')
        }, err => {
          assert.equal(err.message, 'Orders were not matchable!: expected false to equal true', 'Incorrect error')
        })
      })
  })

  it('should fail with expiration time prior to now', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        var buy = makeOrder(exchangeInstance.address, true)
        var sell = makeOrder(exchangeInstance.address, false)
        sell.side = 1
        buy.expirationTime = new BigNumber(Math.pow(10, 1))
        return matchOrder(buy, sell, () => {
          assert.equal(true, false, 'Matching was allowed with expiration time prior to now')
        }, err => {
          assert.equal(err.message, 'Orders were not matchable!: expected false to equal true', 'Incorrect error')
        })
      })
  })

  it('should succeed with real token transfer', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          sell.salt = 2
          buy.salt = 3
          buy.paymentToken = tokenInstance.address
          sell.paymentToken = tokenInstance.address
          buy.basePrice = new BigNumber(10)
          sell.basePrice = new BigNumber(10)
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should succeed with real fee', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          sell.salt = 4
          buy.salt = 5
          buy.makerRelayerFee = 10
          buy.takerRelayerFee = 10
          sell.makerRelayerFee = 10
          sell.takerRelayerFee = 10
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should succeed with real fee, opposite maker-taker', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, false)
          var sell = makeOrder(exchangeInstance.address, true)
          sell.side = 1
          sell.salt = 4
          buy.salt = 5
          buy.makerRelayerFee = 10
          buy.takerRelayerFee = 10
          sell.makerRelayerFee = 10
          sell.takerRelayerFee = 10
          return matchOrder(buy, sell, () => {}, err => {
            assert.equal(false, err, 'Orders should have matched')
          })
        })
      })
  })

  it('should fail with real fee but insufficient amount', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          sell.salt = 4
          buy.salt = 5
          buy.makerRelayerFee = new BigNumber(10).pow(18)
          buy.takerRelayerFee = new BigNumber(10).pow(18)
          sell.makerRelayerFee = new BigNumber(10).pow(18)
          sell.takerRelayerFee = new BigNumber(10).pow(18)
          return matchOrder(buy, sell, () => {
            assert.equal(true, false, 'Matching was allowed with too high fee')
          }, err => {
            assert.equal(err.message, 'VM Exception while processing transaction: revert')
          })
        })
      })
  })

  it('should fail with real fee but unmatching fees', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          sell.salt = 42312
          buy.salt = 5123
          buy.makerRelayerFee = 10
          buy.takerRelayerFee = 10
          sell.makerRelayerFee = 0
          sell.takerRelayerFee = 0
          return matchOrder(buy, sell, () => {
            assert.equal(true, false, 'Matching was allowed with unmatching fees')
          }, err => {
            assert.equal(err.message, 'VM Exception while processing transaction: revert')
          })
        })
      })
  })

  it('should fail with real fee but unmatching fees, opposite maker/taker', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, false)
          var sell = makeOrder(exchangeInstance.address, true)
          sell.side = 1
          sell.salt = 423122
          buy.salt = 51323
          buy.makerRelayerFee = 0
          buy.takerRelayerFee = 0
          sell.makerRelayerFee = 10
          sell.takerRelayerFee = 10
          return matchOrder(buy, sell, () => {
            assert.equal(true, false, 'Matching was allowed with unmatching fees')
          }, err => {
            assert.equal(err.message, 'VM Exception while processing transaction: revert')
          })
        })
      })
  })

  it('should succeed with successful static call', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          buy.salt = 40
          sell.salt = 50
          return TestStatic.deployed().then(staticInstance => {
            buy.staticTarget = staticInstance.address
            const staticInst = new web3.eth.Contract(TestStatic.abi, staticInstance.address)
            buy.staticExtradata = staticInst.methods.alwaysSucceed().encodeABI()
            return matchOrder(buy, sell, () => {}, err => {
              assert.equal(false, err, 'Orders should have matched')
            })
          })
        })
      })
  })

  it('should succeed with successful static call sell-side', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          buy.salt = 404
          sell.salt = 505
          return TestStatic.deployed().then(staticInstance => {
            sell.staticTarget = staticInstance.address
            const staticInst = new web3.eth.Contract(TestStatic.abi, staticInstance.address)
            sell.staticExtradata = staticInst.methods.alwaysSucceed().encodeABI()
            return matchOrder(buy, sell, () => {}, err => {
              assert.equal(false, err, 'Orders should have matched')
            })
          })
        })
      })
  })

  it('should succeed with successful static call both-side', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          buy.salt = 4043
          sell.salt = 5053
          return TestStatic.deployed().then(staticInstance => {
            sell.staticTarget = staticInstance.address
            const staticInst = new web3.eth.Contract(TestStatic.abi, staticInstance.address)
            sell.staticExtradata = staticInst.methods.alwaysSucceed().encodeABI()
            buy.staticTarget = staticInstance.address
            buy.staticExtradata = staticInst.methods.alwaysSucceed().encodeABI()
            return matchOrder(buy, sell, () => {}, err => {
              assert.equal(false, err, 'Orders should have matched')
            })
          })
        })
      })
  })

  it('should fail with unsuccessful static call', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          buy.salt = 41
          sell.salt = 55
          return TestStatic.deployed().then(staticInstance => {
            buy.staticTarget = staticInstance.address
            const staticInst = new web3.eth.Contract(TestStatic.abi, staticInstance.address)
            buy.staticExtradata = staticInst.methods.alwaysFail().encodeABI()
            return matchOrder(buy, sell, () => {
              assert.equal(true, false, 'Matching was allowed with failed static call')
            }, err => {
              assert.equal(err.message, 'VM Exception while processing transaction: revert')
            })
          })
        })
      })
  })

  it('should fail with unsuccessful static call sell-side', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken.deployed().then(tokenInstance => {
          var buy = makeOrder(exchangeInstance.address, true)
          var sell = makeOrder(exchangeInstance.address, false)
          sell.side = 1
          buy.salt = 419
          sell.salt = 559
          return TestStatic.deployed().then(staticInstance => {
            sell.staticTarget = staticInstance.address
            const staticInst = new web3.eth.Contract(TestStatic.abi, staticInstance.address)
            sell.staticExtradata = staticInst.methods.alwaysFail().encodeABI()
            return matchOrder(buy, sell, () => {
              assert.equal(true, false, 'Matching was allowed with failed static call')
            }, err => {
              assert.equal(err.message, 'VM Exception while processing transaction: revert')
            })
          })
        })
      })
  })

  it('should fail after proxy revocation', () => {
    return WyvernProxyRegistry
      .deployed()
      .then(registryInstance => {
        return registryInstance.proxies(accounts[0])
          .then(proxy => {
            const proxyInst = new web3.eth.Contract(AuthenticatedProxy.abi, proxy)
            return proxyInst.methods.setRevoke(true).send({from: accounts[0]}).then(() => {
              return WyvernExchange
                .deployed()
                .then(exchangeInstance => {
                  var buy = makeOrder(exchangeInstance.address, true)
                  var sell = makeOrder(exchangeInstance.address, false)
                  sell.side = 1
                  sell.salt = 40
                  buy.salt = 41
                  return matchOrder(buy, sell, () => {
                    assert.equal(true, false, 'Matching was allowed with proxy revocation')
                    return proxyInst.methods.setRevoke(false).send({from: accounts[0]}).then(() => {
                      return proxyInst.methods.revoked().call({from: accounts[0]}).then(ret => {
                        console.log('checked revocation')
                        assert.equal(ret, false, 'Revocation was not reversed')
                      })
                    })
                  }, err => {
                    assert.equal(err.message, 'VM Exception while processing transaction: revert')
                  })
                })
            })
          })
      })
  })

  it('should display final gas', () => {
    finalGas()
  })
})
