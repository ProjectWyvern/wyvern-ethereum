module.exports = {
  norpc: true,
  skipFiles: ['WyvernExchange.sol', 'exchange/Exchange.sol'],
  copyPackages: ['zeppelin-solidity'],
  testCommand: 'truffle test',
};
