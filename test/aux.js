const MerkleTree = require('../utxo-merkle-proof/index.js')
const fs = require('fs')
const bs58check = require('bs58check')
const web3 = require('web3')

const mtStart = Date.now() / 1000
const utxoMerkleTree = MerkleTree.fromJSON(JSON.parse(fs.readFileSync('../utxo-merkle-proof/data/merkleTree.json')))
const utxoMerkleRoot = utxoMerkleTree.getHexRoot()
const mtEnd = Date.now() / 1000
console.log('Loaded UTXO merkle tree in ' + (mtEnd - mtStart) + 's - tree root: ' + utxoMerkleTree.getHexRoot())

const usStart = Date.now() / 1000
const utxoSet = JSON.parse(fs.readFileSync('../utxo-merkle-proof/data/utxos.json'))
const usEnd = Date.now() / 1000
const utxoAmount = utxoSet.reduce((x, y) => x + y.satoshis, 0)
console.log('Loaded complete UTXO set in ' + (usEnd - usStart) + 's - total UTXOs: ' + utxoSet.length + ', total amount (Satoshis): ' + utxoAmount)

const hashUTXO = (utxo) => {
  const rawAddr = bs58check.decode(utxo.address).slice(1, 21).toString('hex')
  return web3.utils.soliditySha3(
    {type: 'bytes32', value: '0x' + utxo.txid},
    {type: 'bytes20', value: '0x' + rawAddr},
    {type: 'uint8', value: utxo.outputIndex},
    {type: 'uint', value: utxo.satoshis}
  )
}

const network = {
  messagePrefix: '\x18Wyvern Signed Message:\n',
  bip32: {
    public: 0x0488b21e,
    private: 0x0488ade4
  },
  pubKeyHash: 73,
  scriptHash: 43,
  wif: 0xc9
}

module.exports = {
  utxoMerkleTree: utxoMerkleTree,
  utxoMerkleRoot: utxoMerkleRoot,
  utxoAmount: utxoAmount,
  utxoSet: utxoSet,
  hashUTXO: hashUTXO,
  network: network
}
