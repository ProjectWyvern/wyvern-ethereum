module.exports = {
  norpc: true,
  skipFiles: ['WyvernExchange.sol', 'exchange/Exchange.sol', 'WyvernDAO.sol', 'dao/DelegatedShareholderAssociation.sol'],
  copyPackages: ['zeppelin-solidity'],
  testCommand: 'truffle test'
}
