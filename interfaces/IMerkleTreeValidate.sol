pragma solidity ^0.6.12;

interface IMerkleTreeValidate{
    function merkleProof(uint256 recorderId, uint256 lastLeafIndex, bytes32 leafHash, bytes32[] calldata merkelTreePath, bool[] calldata isLeftNode) external view returns (bool);
}