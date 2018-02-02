/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernExchange = artifacts.require('WyvernExchange')
const WyvernProxyRegistry = artifacts.require('WyvernProxyRegistry')
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

const hashOrder = (order) => {
  const partOne = Buffer.from(web3.utils.soliditySha3(
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
  ).slice(2), 'hex')
  const partTwo = Buffer.from(web3.utils.soliditySha3(
    {type: 'address', value: order.staticTarget},
    {type: 'bytes', value: order.staticExtradata},
    {type: 'address', value: order.paymentToken},
    {type: 'uint', value: new BigNumber(order.basePrice)},
    {type: 'uint', value: new BigNumber(order.extra)},
    {type: 'uint', value: new BigNumber(order.listingTime)},
    {type: 'uint', value: new BigNumber(order.expirationTime)},
    {type: 'uint', value: order.salt}
  ).slice(2), 'hex')
  return Buffer.concat([partOne, partTwo]).toString('hex')
}

const hashToSign = (order) => {
  const partOne = web3.utils.soliditySha3(
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
  ).toString('hex')
  const partTwo = web3.utils.soliditySha3(
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
    {type: 'bytes32', value: partOne},
    {type: 'bytes32', value: partTwo}
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

  it('should disallow false complex calldata match', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x0000000000000000', '0x00', '0x00ff00ff00ff00ff', '0x00').then(res => {
          assert.equal(res, false, 'Complex calldata match was not allowed')
        })
      })
  })

  it('should revert on different bytecode size', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return exchangeInstance.orderCalldataCanMatch.call('0x0000000000000000', '0x00', '0x00ff00ff00ff00', '0x00').then(() => {
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

  const makeOrder = (exchange, isMaker) => ({
    exchange: exchange,
    maker: accounts[0],
    taker: accounts[0],
    makerFee: 0,
    takerFee: 0,
    feeRecipient: isMaker ? accounts[0] : '0x0000000000000000000000000000000000000000',
    side: 0,
    saleKind: 0,
    target: accounts[0],
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
        const hash = hashToSign(order)
        return exchangeInstance.hashOrder_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
        const order = makeOrder(exchangeInstance.address)
        order.saleKind = 0
        order.listingTime = 1
        order.expirationTime = 1000
        const hash = hashOrder(order)
        return web3.eth.sign(hash, accounts[0]).then(signature => {
          signature = signature.substr(2)
          const r = '0x' + signature.slice(0, 64)
          const s = '0x' + signature.slice(64, 128)
          const v = 27 + parseInt('0x' + signature.slice(128, 130), 16)
          return exchangeInstance.validateOrder_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
            order.side,
            order.saleKind,
            order.howToCall,
            order.calldata,
            order.replacementPattern,
            order.staticExtradata,
            v, r, s
          ).then(ret => {
            assert.equal(ret, true, 'Order did not validate')
            return exchangeInstance.calculateCurrentPrice_.call(
              [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
              [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
            [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
            [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
            return exchangeInstance.calculateFinalPrice.call(0, 1, 100, 100, time - 50, time + 50).then(price => {
              assert.equal(price.toNumber(), 150, 'Incorrect price')
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
          [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
          [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
        return exchangeInstance.approveOrder_(
          [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
          [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
          order.side,
          order.saleKind,
          order.howToCall,
          order.calldata,
          order.replacementPattern,
          order.staticExtradata,
          true
        ).then(() => {
          return exchangeInstance.validateOrder_.call(
            [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
            [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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
              [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
              order.side,
              order.saleKind,
              order.howToCall,
              order.calldata,
              order.replacementPattern,
              order.staticExtradata,
              0, '0x', '0x'
            ).then(() => {
              return exchangeInstance.validateOrder_.call(
                [order.exchange, order.maker, order.taker, order.feeRecipient, order.target, order.staticTarget, order.paymentToken],
                [order.makerFee, order.takerFee, order.extra, order.listingTime, order.expirationTime, order.salt],
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

  const matchOrder = (buy, sell, thenFunc, catchFunc) => {
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
          return web3.eth.sign(sellHash, accounts[0]).then(signature => {
            signature = signature.substr(2)
            const sr = '0x' + signature.slice(0, 64)
            const ss = '0x' + signature.slice(64, 128)
            const sv = 27 + parseInt('0x' + signature.slice(128, 130), 16)
            return exchangeInstance.ordersCanMatch_.call(
              [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken, sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
              [buy.makerFee, buy.takerFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerFee, sell.takerFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
              [buy.side, buy.saleKind, buy.howToCall, sell.side, sell.saleKind, sell.howToCall],
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
                [buy.makerFee, buy.takerFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerFee, sell.takerFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
                [buy.side, buy.saleKind, buy.howToCall, sell.side, sell.saleKind, sell.howToCall],
                buy.calldata,
                sell.calldata,
                buy.replacementPattern,
                sell.replacementPattern,
                buy.staticExtradata,
                sell.staticExtradata
              ).then(matchPrice => {
                assert.equal(matchPrice.toNumber(), buy.basePrice.toNumber(), 'Incorrect match price!')
                return exchangeInstance.atomicMatch_(
                  [buy.exchange, buy.maker, buy.taker, buy.feeRecipient, buy.target, buy.staticTarget, buy.paymentToken, sell.exchange, sell.maker, sell.taker, sell.feeRecipient, sell.target, sell.staticTarget, sell.paymentToken],
                  [buy.makerFee, buy.takerFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerFee, sell.takerFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
                  [buy.side, buy.saleKind, buy.howToCall, sell.side, sell.saleKind, sell.howToCall],
                  buy.calldata,
                  sell.calldata,
                  buy.replacementPattern,
                  sell.replacementPattern,
                  buy.staticExtradata,
                  sell.staticExtradata,
                  [bv, sv],
                  [br, bs, sr, ss]).then(thenFunc)
              })
            })
          })
        })
      }).catch(catchFunc)
  }

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
          [buy.makerFee, buy.takerFee, buy.basePrice, buy.extra, buy.listingTime, buy.expirationTime, buy.salt, sell.makerFee, sell.takerFee, sell.basePrice, sell.extra, sell.listingTime, sell.expirationTime, sell.salt],
          [buy.side, buy.saleKind, buy.howToCall, sell.side, sell.saleKind, sell.howToCall],
          buy.calldata,
          sell.calldata,
          buy.replacementPattern,
          sell.replacementPattern,
          buy.staticExtradata,
          sell.staticExtradata,
          [0, 0],
          ['0x', '0x', '0x', '0x']
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

  it('should allow approval', () => {
    return WyvernExchange
      .deployed()
      .then(exchangeInstance => {
        return TestToken
          .deployed()
          .then(tokenInstance => {
            return tokenInstance.approve(exchangeInstance.address, 1000000)
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
          buy.makerFee = 10
          buy.takerFee = 10
          sell.makerFee = 10
          sell.takerFee = 10
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
          buy.makerFee = 10
          buy.takerFee = 10
          sell.makerFee = 10
          sell.takerFee = 10
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
          buy.makerFee = new BigNumber(10).pow(18)
          buy.takerFee = new BigNumber(10).pow(18)
          sell.makerFee = new BigNumber(10).pow(18)
          sell.takerFee = new BigNumber(10).pow(18)
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
          buy.makerFee = 10
          buy.takerFee = 10
          sell.makerFee = 0
          sell.takerFee = 0
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
          buy.makerFee = 0
          buy.takerFee = 0
          sell.makerFee = 10
          sell.takerFee = 10
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
})
