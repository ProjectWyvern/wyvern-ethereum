/* global artifacts:false, it:false, contract:false, assert:false */

const Web3 = require('web3')
const BigNumber = require('bignumber.js')

const TestDAO = artifacts.require('TestDAO')
const TestToken = artifacts.require('TestToken')

const web3 = new Web3()

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

  it('should not allow anyone to change the voting rules', () => {
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.changeVotingRules.call(0, 0)
      })
      .then(ret => {
        assert.equal(true, false, 'Anyone was allowed to change the voting rules')
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

  it('should allow receipt of tokens', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return TestToken
          .deployed()
          .then(tokenInstance => {
            return tokenInstance.approve.sendTransaction(daoInstance.address, amount)
              .then(() => {
                return daoInstance.receiveApproval.call(accounts[0], amount, tokenInstance.address, '0x')
              })
              .then(ret => {
                assert.equal(ret.length, 0, 'Was not able to receive tokens')
              })
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

  it('should allow voting, count votes correctly, then allow proposal execution', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.newProposal.sendTransaction(daoInstance.address, 0, '0x', '0x')
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
            return daoInstance.checkProposalCode.call(0, daoInstance.address, 0, '0x')
          })
          .then(ret => {
            assert.equal(ret, true, 'Proposal code did not match')
            return daoInstance.executeProposal.call(0, '0x')
          })
          .then(ret => {
            assert.equal(ret.length, 0, 'Proposal was not executed')
          })
      })
  })

  it('should allow the DAO to change its own voting rules', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        const abi = new web3.eth.Contract(daoInstance.abi, daoInstance.address).methods.changeVotingRules(2, 0).encodeABI()
        return daoInstance.newProposal.sendTransaction(daoInstance.address, 0, '0x', abi)
          .then(() => {
            return daoInstance.vote.sendTransaction(1, true)
          })
          .then(() => {
            return daoInstance.countVotes.call(1)
          })
          .then(ret => {
            const yea = ret[0]
            const nay = ret[1]
            const quorum = ret[2]
            assert.equal(yea.equals(amount), true, 'Incorrect yea count')
            assert.equal(nay.equals(0), true, 'Incorrect nay count')
            assert.equal(quorum.equals(amount), true, 'Incorrect quorum count')
            return daoInstance.checkProposalCode.call(1, daoInstance.address, 0, abi)
          })
          .then(ret => {
            assert.equal(ret, true, 'Proposal code did not match')
            return daoInstance.executeProposal.sendTransaction(1, abi)
          })
          .then(() => {
            return daoInstance.minimumQuorum.call()
          })
          .then(ret => {
            assert.equal(ret, 2, 'Voting rules were not changed')
          })
      })
  })

  it('should not allow execution of a failed proposal', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        const abi = new web3.eth.Contract(daoInstance.abi, daoInstance.address).methods.changeVotingRules(3, 3).encodeABI()
        return daoInstance.newProposal.sendTransaction(daoInstance.address, 0, '0x', abi)
          .then(() => {
            return daoInstance.vote.sendTransaction(2, false)
          })
          .then(() => {
            return daoInstance.countVotes.call(2)
          })
          .then(ret => {
            const yea = ret[0]
            const nay = ret[1]
            const quorum = ret[2]
            assert.equal(yea.equals(0), true, 'Incorrect yea count')
            assert.equal(nay.equals(amount), true, 'Incorrect nay count')
            assert.equal(quorum.equals(amount), true, 'Incorrect quorum count')
            return daoInstance.checkProposalCode.call(2, daoInstance.address, 0, abi)
          })
          .then(ret => {
            assert.equal(ret, true, 'Proposal code did not match')
            return daoInstance.executeProposal.sendTransaction(2, abi)
          })
          .then(() => {
            return daoInstance.minimumQuorum.call()
          })
          .then(ret => {
            assert.equal(ret, 2, 'The failed proposal was executed')
          })
      })
  })

  it('should not allow spending the locked tokens', () => {
    const amount = new BigNumber(Math.pow(10, 18 + 7))
    return TestDAO
      .deployed()
      .then(daoInstance => {
        return daoInstance.minimumQuorum.call()
          .then(() => {
            return TestToken
              .deployed()
              .then(tokenInstance => {
                const abi = new web3.eth.Contract(tokenInstance.abi, tokenInstance.address).methods.transfer(accounts[0], amount).encodeABI()
                return daoInstance.newProposal.sendTransaction(tokenInstance.address, 0, '0x', abi)
                  .then(() => {
                    return daoInstance.vote.sendTransaction(3, true)
                  })
                  .then(() => {
                    return daoInstance.executeProposal.sendTransaction(3, abi)
                  })
                  .catch(err => {
                    assert.equal(err.message, 'VM Exception while processing transaction: revert', 'Incorrect error')
                  })
              })
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
