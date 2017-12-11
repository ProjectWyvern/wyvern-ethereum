/* global artifacts:false, it:false, contract:false, assert:false */

const web3 = require('web3')
const BigNumber = require('bignumber.js')

const TestDAO = artifacts.require('TestDAO')
const TestToken = artifacts.require('TestToken')

contract('TestDAO', (accounts) => {
  it('should not allow delegation of more shares than owned', () => {
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.setDelegateAndLockTokens.call((new BigNumber(Math.pow(10, 18 + 7)).mul(3)), accounts[1])
      })
      .then(ret => {
        assert.equal(true, false, 'Delegation was allowed without shares')
      })
      .catch(err => {
        assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
      })
  })

  it('should allow share delegation after token allowance', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return TestToken
          .deployed()
          .then(tokenInstance => {
            return tokenInstance.approve.sendTransaction(daoInstance.address, amount)
          })
          .then(() => {
            return daoInstance.setDelegateAndLockTokens.call(amount, accounts[1])
          })
      })
  })

  it('should not allow share delegation twice, and should allow undelegation', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.setDelegateAndLockTokens.sendTransaction(amount, accounts[1])
          .then(() => {
            return daoInstance.setDelegateAndLockTokens.call(amount, accounts[1])
          })
          .then(() => {
            assert.equal(true, false, 'Delegation was allowed twice')
          })
          .catch(err => {
            assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
            return daoInstance.clearDelegateAndUnlockTokens.call()
              .then(ret => {
                assert.equal(ret.equals(amount), true, 'Incorrect amount of tokens undelegated')
              })
          })
      })
  })

  it('should allow new proposal creation', () => {
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.newProposal.call(accounts[1], 0, '0x', '0x')
      })
      .then(ret => {
        assert.equal(ret.equals(new BigNumber(0)), true, 'Incorrect proposal ID')
      })
  })

  it('should allow voting and count votes correctly', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.newProposal.sendTransaction(accounts[1], 0, '0x', '0x')
          .then(() => {
            return daoInstance.vote.sendTransaction(0, true)
          })
          .then(() => {
            return daoInstance.countVotes.call(0)
          })
          .then(ret => {
            const yea = ret[0]
            const nay = ret[1]
            const quorum = ret[2]
            assert.equal(yea.equals(amount), true, 'Incorrect yea count')
            assert.equal(nay.equals(0), true, 'Incorrect nay count')
            assert.equal(quorum.equals(amount), true, 'Incorrect quorum count')
          })
      })
  })

  it('should log receipt of Ether', () => {
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.sendTransaction({value: web3.utils.toWei(0.1)})
      })
      .then(ret => {
        assert.equal(ret.logs.length, 1, 'No logs were fired')
      })
  })
})
