module.exports = {
  port: 8545,
  copyPackages: ['zeppelin-solidity'],
  skipFiles: ['common/ArrayUtils.sol'],
  compileCommand: '../node_modules/.bin/truffle compile',
  testCommand: '../node_modules/.bin/truffle test --network coverage'
}
