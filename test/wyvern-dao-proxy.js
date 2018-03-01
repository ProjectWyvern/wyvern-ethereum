/* global artifacts:false, it:false, contract:false, assert:false */

const TestToken = artifacts.require('TestToken')
const WyvernDAOProxy = artifacts.require('WyvernDAOProxy')
const WyvernAtomicizer = artifacts.require('WyvernAtomicizer')

const Web3 = require('web3')
const web3 = new Web3()

contract('WyvernDAOProxy', (accounts) => {
  const WithContracts = (func) => {
    return TestToken.deployed().then(tokenInstance => {
      return WyvernDAOProxy.deployed().then(daoProxyInstance => {
        return WyvernAtomicizer.deployed().then(atomicizerInstance => {
          return func({ tokenInstance, daoProxyInstance, atomicizerInstance })
        })
      })
    })
  }

  it('should accept tokens', () => {
    return WithContracts(({ tokenInstance, daoProxyInstance }) => {
      return tokenInstance.transfer(daoProxyInstance.address, 10).then(() => {
        return tokenInstance.balanceOf.call(daoProxyInstance.address).then(amount => {
          assert.equal(amount.toNumber(), 10, 'Incorrect amount')
        })
      })
    })
  })

  it('should send tokens once with delegatecall', () => {
    return WithContracts(({ tokenInstance, daoProxyInstance, atomicizerInstance }) => {
      const tokenContract = new web3.eth.Contract(tokenInstance.abi, tokenInstance.address)
      const encodedTransfer = tokenContract.methods.transfer(tokenInstance.address, 2).encodeABI()
      const atomicizerContract = new web3.eth.Contract(atomicizerInstance.abi, atomicizerInstance.address)
      const encodedAtomic = atomicizerContract.methods.atomicize([tokenInstance.address], [0], [(encodedTransfer.length - 2) / 2], encodedTransfer).encodeABI()
      return daoProxyInstance.delegateProxyAssert(atomicizerInstance.address, encodedAtomic).then(() => {
        return tokenInstance.balanceOf.call(daoProxyInstance.address).then(amount => {
          assert.equal(amount.toNumber(), 8, 'Incorrect amount')
        })
      })
    })
  })

  it('should send tokens twice with delegatecall', () => {
    return WithContracts(({ tokenInstance, daoProxyInstance, atomicizerInstance }) => {
      const tokenContract = new web3.eth.Contract(tokenInstance.abi, tokenInstance.address)
      const encodedTransfer = tokenContract.methods.transfer(tokenInstance.address, 2).encodeABI()
      const atomicizerContract = new web3.eth.Contract(atomicizerInstance.abi, atomicizerInstance.address)
      const encodedAtomic = atomicizerContract.methods.atomicize([tokenInstance.address, tokenInstance.address], [0, 0], [(encodedTransfer.length - 2) / 2, (encodedTransfer.length - 2) / 2], encodedTransfer + encodedTransfer.slice(2)).encodeABI()
      return daoProxyInstance.delegateProxyAssert(atomicizerInstance.address, encodedAtomic).then(() => {
        return tokenInstance.balanceOf.call(daoProxyInstance.address).then(amount => {
          assert.equal(amount.toNumber(), 4, 'Incorrect amount')
        })
      })
    })
  })

  it('should fail with failed first transfer on delegatecall', () => {
    return WithContracts(({ tokenInstance, daoProxyInstance, atomicizerInstance }) => {
      const tokenContract = new web3.eth.Contract(tokenInstance.abi, tokenInstance.address)
      const encodedTransferA = tokenContract.methods.transfer(tokenInstance.address, 5).encodeABI()
      const encodedTransferB = tokenContract.methods.transfer(tokenInstance.address, 1).encodeABI()
      const atomicizerContract = new web3.eth.Contract(atomicizerInstance.abi, atomicizerInstance.address)
      const encodedAtomic = atomicizerContract.methods.atomicize([tokenInstance.address, tokenInstance.address], [0, 0], [(encodedTransferA.length - 2) / 2, (encodedTransferB.length - 2) / 2], encodedTransferA + encodedTransferB.slice(2)).encodeABI()
      return daoProxyInstance.delegateProxyAssert(atomicizerInstance.address, encodedAtomic).then(() => {
        assert.equal(true, false, 'Should have reverted')
      }).catch(() => {
        return tokenInstance.balanceOf.call(daoProxyInstance.address).then(amount => {
          assert.equal(amount.toNumber(), 4, 'Incorrect amount')
        })
      })
    })
  })
})
