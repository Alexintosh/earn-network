const Gira = artifacts.require("Girasol");



module.exports = function(deployer, network , accounts) {
  // const bzx1 = require("../node_modules/@bzxnetwork/contracts/migrations/2_deploy_BZxVault.js");
  // console.log(bzx1);

  deployer.deploy(Gira);
};
