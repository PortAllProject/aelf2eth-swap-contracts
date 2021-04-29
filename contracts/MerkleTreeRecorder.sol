pragma solidity ^0.6.12;

import "../interfaces/IMerkleTreeValidate.sol";
import "../interfaces/IRecordMerkleTree.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
pragma experimental ABIEncoderV2;

contract MerkleTreeRecorder is IMerkleTreeValidate, IRecordMerkleTree, Ownable {
    using SafeMath for uint256;

    struct Recorder {
        address admin;
        uint256 maximalLeafCount;
    }

    struct MerkleTree {
        uint256 firstLeafIndex;
        uint256 lastLeafIndex;
        bytes32 merkleTreeRoot;
    }

    uint256 public merkleTreeRecorderCount;

    mapping(uint256 => Recorder) public recorders;

    mapping(uint256 => uint256) internal lastRecordedLeafIndex;

    mapping(uint256 => uint256) public satisfiedMerkleTreeCount;

    mapping(uint256 => mapping(uint256 => MerkleTree))
        public satisfiedMerkleTrees;

    mapping(uint256 => mapping(uint256 => MerkleTree))
        public unSatisfiedMerkleTrees;

    bytes32 constant invalidHash = bytes32(0);

    event RecorderCreated(
        address indexed admin,
        uint256 maximalLeafCount,
        uint256 recorderId
    );
    event MerkleTreeRecorded(uint256 indexed recorderId, uint256 lastLeafIndex);

    modifier merkleTreeGenerated(uint256 _recorderId) {
        require(
            lastRecordedLeafIndex[_recorderId] != 0,
            "there is not any merkle trees generated"
        );
        _;
    }

    function createRecorder(address _admin, uint256 _maximalLeafCount)
        external
        onlyOwner
    {
        uint256 currentRecordCount = merkleTreeRecorderCount;
        recorders[currentRecordCount] = Recorder(_admin, _maximalLeafCount);
        lastRecordedLeafIndex[currentRecordCount] = 0;
        emit RecorderCreated(_admin, _maximalLeafCount, currentRecordCount);
        merkleTreeRecorderCount = currentRecordCount.add(1);
    }

    function recordMerkleTree(
        uint256 _recorderId,
        uint256 _lastLeafIndex,
        bytes32 _merkleTreeRoot
    ) external override {
        Recorder memory recorder = recorders[_recorderId];
        require(recorder.admin == msg.sender, "not admin");
        uint256 currentLeafIndex = lastRecordedLeafIndex[_recorderId];
        _lastLeafIndex = _lastLeafIndex.add(1);
        require(_lastLeafIndex > currentLeafIndex, "it is not a new tree");
        require(
            _lastLeafIndex.sub(currentLeafIndex) <= recorder.maximalLeafCount,
            "satisfied MerkleTree absent"
        );
        uint256 currentSatisfiedTreeCount =
            satisfiedMerkleTreeCount[_recorderId];
        _lastLeafIndex = _lastLeafIndex.sub(1);
        uint256 newRecordedLeafLocated =
            _lastLeafIndex.div(recorder.maximalLeafCount);
        uint256 indexShouldBeCount =
            currentSatisfiedTreeCount.add(1).mul(recorder.maximalLeafCount).sub(
                1
            );
        if (newRecordedLeafLocated > currentSatisfiedTreeCount) {
            require(
                currentLeafIndex == indexShouldBeCount,
                "unable to record the tree"
            );
        }
        MerkleTree memory merkleTree =
            MerkleTree(
                currentSatisfiedTreeCount.mul(recorder.maximalLeafCount),
                _lastLeafIndex,
                _merkleTreeRoot
            );
        if (_lastLeafIndex == indexShouldBeCount) {
            uint256 currentStatisfiedMerkleTreeCount =
                satisfiedMerkleTreeCount[_recorderId];
            satisfiedMerkleTrees[_recorderId][
                currentStatisfiedMerkleTreeCount
            ] = merkleTree;
            satisfiedMerkleTreeCount[
                _recorderId
            ] = currentStatisfiedMerkleTreeCount.add(1);
        } else {
            uint256 currentIndex =
                _lastLeafIndex.mod(recorder.maximalLeafCount);
            unSatisfiedMerkleTrees[_recorderId][currentIndex] = merkleTree;
        }
        lastRecordedLeafIndex[_recorderId] = _lastLeafIndex.add(1);
        emit MerkleTreeRecorded(_recorderId, _lastLeafIndex);
    }

    function GetLeafLocatedMerkleTree(uint256 _recorderId, uint256 _leafIndex)
        public
        view
        merkleTreeGenerated(_recorderId)
        returns (MerkleTree memory)
    {
        uint256 lastRecordLeafIndex = lastRecordedLeafIndex[_recorderId].sub(1);
        require(lastRecordLeafIndex >= _leafIndex, "not recorded yet");
        return
            GetMerkleTreeByDefaultIndex(
                _recorderId,
                _leafIndex,
                lastRecordLeafIndex,
                false
            );
    }

    function getMerkleTree(uint256 _recorderId, uint256 _leafIndex)
        public
        view
        merkleTreeGenerated(_recorderId)
        returns (MerkleTree memory)
    {
        uint256 lastRecordLeafIndex = lastRecordedLeafIndex[_recorderId].sub(1);
        require(lastRecordLeafIndex >= _leafIndex, "not recorded yet");
        return
            GetMerkleTreeByDefaultIndex(
                _recorderId,
                _leafIndex,
                _leafIndex,
                true
            );
    }

    function merkleProof(
        uint256 _recorderId,
        uint256 _lastLeafIndex,
        bytes32 _leafHash,
        bytes32[] calldata _merkelTreePath,
        bool[] calldata _isLeftNode
    ) external view override returns (bool) {
        if (
            lastRecordedLeafIndex[_recorderId] == 0 ||
            _merkelTreePath.length != _isLeftNode.length
        ) {
            return false;
        }
        MerkleTree memory merkleTree =
            getMerkleTree(_recorderId, _lastLeafIndex);
        for (uint256 i = 0; i < _merkelTreePath.length; i++) {
            if (_isLeftNode[i]) {
                _leafHash = sha256(abi.encode(_merkelTreePath[i], _leafHash));
                continue;
            }
            _leafHash = sha256(abi.encode(_leafHash, _merkelTreePath[i]));
        }
        return _leafHash == merkleTree.merkleTreeRoot;
    }

    function getLastRecordedLeafIndex(uint256 _recorderId)
        external
        view
        merkleTreeGenerated(_recorderId)
        returns (uint256)
    {
        return lastRecordedLeafIndex[_recorderId].sub(1);
    }

    function GetMerkleTreeByDefaultIndex(
        uint256 _recorderId,
        uint256 _leafIndex,
        uint256 _defaultIndex,
        bool _isCheck
    ) private view returns (MerkleTree memory) {
        Recorder memory recorder = recorders[_recorderId];
        uint256 satisfiedMerkleTreeIndex =
            _leafIndex.div(recorder.maximalLeafCount);
        if (satisfiedMerkleTreeIndex < satisfiedMerkleTreeCount[_recorderId]) {
            return satisfiedMerkleTrees[_recorderId][satisfiedMerkleTreeIndex];
        }
        MerkleTree memory merkleTree =
            unSatisfiedMerkleTrees[_recorderId][
                _defaultIndex.mod(recorder.maximalLeafCount)
            ];
        if (_isCheck) {
            require(
                merkleTree.lastLeafIndex == _defaultIndex &&
                    merkleTree.merkleTreeRoot != invalidHash,
                "tree not recorded"
            );
        }
        return merkleTree;
    }
}
