/* global artifacts:false, it:false, contract:false, assert:false */

const TestToken = artifacts.require('TestToken')
const TestBank = artifacts.require('TestBank')

const BigNumber = require('bignumber.js')

contract('TestBank', (accounts) => {
  const TokenAndBank = (func) => {
    return TestToken
      .deployed()
      .then(tokenInstance => {
        return TestBank
          .deployed()
          .then(bankInstance => {
            return func({ tokenInstance, bankInstance })
          })
      })
  }

  it('should set correct balance, available, and locked after deposit', () => {
    return TokenAndBank(({ tokenInstance, bankInstance }) => {
      return tokenInstance.balanceOf.call(accounts[0]).then(amount => {
        return tokenInstance.approve(bankInstance.address, amount).then(() => {
          return bankInstance.deposit(accounts[0], tokenInstance.address, amount)
        }).then(() => {
          return bankInstance.balanceFor.call(accounts[0], tokenInstance.address).then(balance => {
            assert.equal(balance.equals(amount), true, 'Balance was not set correctly after deposit')
          }).then(() => {
            return bankInstance.availableFor.call(accounts[0], tokenInstance.address).then(available => {
              assert.equal(available.equals(amount), true, 'Available was not set correctly after deposit')
            }).then(() => {
              return bankInstance.lockedFor(accounts[0], tokenInstance.address).then(locked => {
                assert.equal(locked.equals(0), true, 'Locked was nonzero')
              })
            })
          })
        })
      })
    })
  })

  it('should set correct balance, available, and locked after withdrawal', () => {
    const amount = new BigNumber(10).pow(25).mul(2)
    return TokenAndBank(({ tokenInstance, bankInstance }) => {
      return bankInstance.withdraw(accounts[0], tokenInstance.address, amount, accounts[0]).then(() => {
        return tokenInstance.balanceOf.call(accounts[0]).then(balance => {
          assert.equal(balance.equals(amount), true, 'Token balance was not set correctly after withdrawal')
        }).then(() => {
          return bankInstance.balanceFor.call(accounts[0], tokenInstance.address).then(balance => {
            assert.equal(balance.equals(0), true, 'Bank balance was not set correctly after withdrawal')
          }).then(() => {
            return bankInstance.availableFor.call(accounts[0], tokenInstance.address).then(available => {
              assert.equal(available.equals(0), true, 'Available was not set correctly after deposit')
            }).then(() => {
              return bankInstance.lockedFor(accounts[0], tokenInstance.address).then(locked => {
                assert.equal(locked.equals(0), true, 'Locked was nonzero')
              })
            })
          })
        })
      })
    })
  })
})
