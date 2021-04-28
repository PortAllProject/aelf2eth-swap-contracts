const TokenSwap = artifacts.require("TokenSwap");
const MerkleTreeRecorderContract = artifacts.require("MerkleTreeRecorder");
module.exports = function (deployer) {
  deployer.deploy(TokenSwap, MerkleTreeRecorderContract.address);
};
