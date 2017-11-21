const Migrations  = artifacts.require('./Migrations.sol');
const WYVToken    = artifacts.require('./WYVToken.sol');


module.exports = (deployer) => {
  deployer.deploy(Migrations);
  deployer.deploy(WYVToken);
};
