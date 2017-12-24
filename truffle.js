module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8546,
      network_id: '*',
      gas: 6700000
    },
    kovan: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gas: 4600000
    },
    rinkeby: {
      host: 'localhost',
      from: '0xb483a98e72a583cc9b45b70cee07ac628d633d69',
      port: 8545,
      network_id: '*',
      gas: 4600000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
}
