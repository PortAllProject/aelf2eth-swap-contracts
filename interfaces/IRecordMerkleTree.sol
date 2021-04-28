
pragma solidity ^0.6.12;

interface IRecordMerkleTree{
    function recordMerkleTree(uint256 recorderId, uint256 lastLeafIndex, bytes32 merkleTreeRoot) external;
}


