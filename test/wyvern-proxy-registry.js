/* global artifacts:false, it:false, contract:false, assert:false */

const WyvernProxyRegistry = artifacts.require('WyvernProxyRegistry')
const TestToken = artifacts.require('TestToken')
const AuthenticatedProxy = artifacts.require('AuthenticatedProxy')
const Web3 = require('web3')
const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

const BigNumber = require('bignumber.js')

contract('WyvernProxyRegistry', (accounts) => {
  it('should allow proxy creation', () => {
    return WyvernProxyRegistry
      .deployed()
      .then(registryInstance => {
        return registryInstance.registerProxy()
          .then(() => {
            return registryInstance.proxies(accounts[0])
              .then(ret => {
                assert.equal(ret.length, 42, 'Proxy was not created')
              })
          })
      })
  })

  it('should allow sending tokens through proxy', () => {
    const amount = new BigNumber(10).pow(25).mul(2)
    return WyvernProxyRegistry
      .deployed()
      .then(registryInstance => {
        return TestToken
          .deployed()
          .then(tokenInstance => {
            return registryInstance.proxies(accounts[0])
              .then(proxy => {
                return tokenInstance.transfer(proxy, amount).then(() => {
                  const abi = new web3.eth.Contract(tokenInstance.abi, tokenInstance.address).methods.transfer(accounts[0], amount).encodeABI()
                  const proxyInst = new web3.eth.Contract(AuthenticatedProxy.abi, proxy)
                  return proxyInst.methods.proxyAssert(tokenInstance.address, 0, abi).send({from: accounts[0]}).then(() => {
                    return tokenInstance.balanceOf.call(accounts[0]).then(balance => {
                      assert.equal(balance.equals(amount), true, 'Tokens were not sent back from proxy')
                    })
                  })
                })
              })
          })
      })
  })

  it('should allow revoke', () => {
    return WyvernProxyRegistry
      .deployed()
      .then(registryInstance => {
        return registryInstance.proxies(accounts[0]).then(proxy => {
          const proxyInst = new web3.eth.Contract(AuthenticatedProxy.abi, proxy)
          return proxyInst.methods.setRevoke(true).send({from: accounts[0]}).then(txHash => {
            return proxyInst.methods.revoked().call().then(revoked => {
              assert.equal(revoked, true, 'Revoked was not set correctly')
            }).then(() => {
              return proxyInst.methods.setRevoke(false).send({from: accounts[0]}).then(() => {
                return proxyInst.methods.revoked().call().then(revoked => {
                  assert.equal(revoked, false, 'Revoked was not reset correctly')
                })
              })
            })
          })
        })
      })
  })
})
