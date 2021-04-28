const CW = artifacts.require("CWToken");
const JUN = artifacts.require("JUNToken");
module.exports = function (deployer) {
  deployer.deploy(CW);
  deployer.deploy(JUN);
};
