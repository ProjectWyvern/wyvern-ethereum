module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gas: 6700000
    },
    kovan: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gas: 6700000
    },
    rinkeby: {
      host: 'localhost',
      from: '0xb483a98e72a583cc9b45b70cee07ac628d633d69',
      port: 8545,
      network_id: '*',
      gas: 6700000,
      gasPrice: 21000000000
    },
    main: {
      host: 'localhost',
      port: 8545,
      from: '0x0084a81668B9A978416aBEB88bC1572816cc7cAC',
      network_id: 1,
      gas: 2000000,
      gasPrice: 4100000000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
}
