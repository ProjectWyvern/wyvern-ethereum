const WyvernToken     = artifacts.require('./WyvernToken.sol');
const WyvernDAO       = artifacts.require('./WyvernDAO.sol');
const WyvernExchange  = artifacts.require('./WyvernExchange.sol');

module.exports = (deployer) => {
  deployer.deploy(WyvernToken);
  deployer.deploy(WyvernDAO);
  deployer.deploy(WyvernExchange);
};
