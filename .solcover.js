module.exports = {
  port: 8545,
  copyPackages: ['openzeppelin-solidity'],
  skipFiles: ['TestStatic.sol', 'common/ArrayUtils.sol', '../openzeppelin-solidity/contracts/math/SafeMath.sol'],
  compileCommand: '../node_modules/.bin/truffle compile',
  testCommand: '../node_modules/.bin/truffle test --network coverage'
}
