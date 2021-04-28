const MerkleTreeRecorderContract = artifacts.require("MerkleTreeRecorder");
module.exports = function (deployer) {
  deployer.deploy(MerkleTreeRecorderContract);
};
