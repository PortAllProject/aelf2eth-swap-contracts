pragma solidity ^0.6.12;

import "../interfaces/IMerkleTreeValidate.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
pragma experimental ABIEncoderV2;

contract TokenSwap {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct SwapInfo {
        uint256 recorderId;
        address controller;
        address[] tokenList;
        uint256 originTokenSizeInByte;
        bool isBigEndian;
    }

    struct SwapPair {
        uint256 swappedAmount;
        uint256 swappedTimes;
        uint256 depositAmount;
        SwapRatio swapRatio;
        bool isUsed;
    }

    struct SwapRatio {
        uint256 originShare;
        uint256 targetShare;
    }

    struct SwapAmounts {
        address receiver;
        mapping(address => uint256) receivedAmounts;
    }

    uint256 public constant maximalOriginTokenRangeSizeInByte = 32;

    uint256 public constant minimalOriginTokenRangeSizeInByte = 4;

    IMerkleTreeValidate public merkleTreeValidtator;

    mapping(bytes32 => SwapInfo) internal swapInfos;

    mapping(bytes32 => mapping(address => SwapPair)) public swapTargetTokenMap;

    mapping(bytes32 => mapping(bytes32 => SwapAmounts)) internal ledger;

    event SwapPairAdded(bytes32 indexed swapId);
    event TokenSwapEvent(
        address indexed receiver,
        address indexed token,
        uint256 amount
    );
    event SwapRatioChanged(
        bytes32 indexed swapId,
        address token,
        SwapRatio swapRatio
    );

    constructor(address _merkleTreeValidtator) public {
        merkleTreeValidtator = IMerkleTreeValidate(_merkleTreeValidtator);
    }

    function createSwap(
        uint256 _recorderId,
        uint248 _originTokenSizeInByte,
        bool _isBigEndian,
        address[] calldata _tokenList,
        uint256[] calldata _depositAmount,
        SwapRatio[] memory _swapRatio
    ) external returns (bytes32) {
        require(
            address(merkleTreeValidtator) != address(0),
            "merkleTreeValidtator has not been initialized"
        );
        bytes32 swapHashId = keccak256(msg.data);
        require(
            swapInfos[swapHashId].controller == address(0),
            "already added"
        );
        require(
            isOriginTokenSizeValid(_originTokenSizeInByte),
            "invalid origin token size"
        );
        require(
            _tokenList.length == _depositAmount.length &&
                _depositAmount.length == _swapRatio.length,
            "invalid paramter"
        );
        SwapInfo memory newSwapInfo =
            SwapInfo(
                _recorderId,
                msg.sender,
                _tokenList,
                _originTokenSizeInByte,
                _isBigEndian
            );
        for (uint256 i = 0; i < _tokenList.length; i++) {
            validtateSwapRatio(_swapRatio[i]);
            swapTargetTokenMap[swapHashId][address(_tokenList[i])] = SwapPair(
                0,
                0,
                _depositAmount[i],
                _swapRatio[i],
                true
            );
            if (_depositAmount[i] == 0) {
                continue;
            }
            IERC20(_tokenList[i]).safeTransferFrom(
                address(msg.sender),
                address(this),
                _depositAmount[i]
            );
        }
        swapInfos[swapHashId] = newSwapInfo;
        emit SwapPairAdded(swapHashId);
        return swapHashId;
    }

    struct MerklePathInfo {
        uint256 lastLeafIndex;
        bytes32 uniqueId;
        bytes32[] merkelTreePath;
        bool[] isLeftNode;
    }

    function swapToken(
        bytes32 _swapId,
        uint256 _amount,
        address _receiverAddress,
        MerklePathInfo calldata _merklePathInfo
    ) external {
        require(
            msg.sender == _receiverAddress,
            "only receiver has permission to swap token"
        );
        require(
            swapInfos[_swapId].controller != address(0),
            "token swap pair not found"
        );
        require(_amount > 0, "invalid amount");
        SwapAmounts storage swapAmouts =
            ledger[_swapId][_merklePathInfo.uniqueId];
        require(swapAmouts.receiver == address(0), "already claimed");
        SwapInfo storage swapInfo = swapInfos[_swapId];
        bytes32 leafHash =
            computeLeafHash(
                _amount,
                _merklePathInfo.uniqueId,
                swapInfo,
                _receiverAddress
            );
        require(
            merkleTreeValidtator.merkleProof(
                swapInfo.recorderId,
                _merklePathInfo.lastLeafIndex,
                leafHash,
                _merklePathInfo.merkelTreePath,
                _merklePathInfo.isLeftNode
            ),
            "failed to swap token"
        );
        address[] memory tokenList = swapInfo.tokenList;
        swapAmouts.receiver = _receiverAddress;
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            SwapPair storage swapPair = swapTargetTokenMap[_swapId][token];
            uint256 targetTokenAmount =
                _amount.mul(swapPair.swapRatio.targetShare).div(
                    swapPair.swapRatio.originShare
                );
            require(
                targetTokenAmount <= swapPair.depositAmount,
                "deposit not enought"
            );
            swapPair.swappedAmount = swapPair.swappedAmount.add(
                targetTokenAmount
            );
            swapPair.swappedTimes = swapPair.swappedTimes.add(1);
            swapPair.depositAmount = swapPair.depositAmount.sub(
                targetTokenAmount
            );
            IERC20(token).transfer(_receiverAddress, targetTokenAmount);
            emit TokenSwapEvent(_receiverAddress, token, targetTokenAmount);
            swapAmouts.receivedAmounts[token] = targetTokenAmount;
        }
    }

    function changeSwapRatio(
        bytes32 _swapId,
        address _token,
        SwapRatio memory _swapRatio
    ) external {
        SwapPair storage swapPair = getSwapPair(_swapId, _token);
        validtateSwapRatio(_swapRatio);
        swapPair.swapRatio = _swapRatio;
        emit SwapRatioChanged(_swapId, _token, _swapRatio);
    }

    function deposit(
        bytes32 _swapId,
        address _token,
        uint256 _amount
    ) external {
        SwapPair storage swapPair = getSwapPair(_swapId, _token);
        swapPair.depositAmount = swapPair.depositAmount.add(_amount);
        IERC20(_token).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
    }

    function withdraw(
        bytes32 _swapId,
        address _token,
        uint256 _amount
    ) external {
        SwapPair storage swapPair = getSwapPair(_swapId, _token);
        uint256 currentDepositAmount = swapPair.depositAmount;
        require(currentDepositAmount >= _amount, "deposit not enough");
        swapPair.depositAmount = currentDepositAmount.sub(_amount);
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function getSwapInfo(bytes32 _swapId)
        external
        view
        returns (
            uint256 _recorderId,
            address _controller,
            uint256 _originTokenSizeInByte,
            bool _isBigEndian,
            address[] memory tokenList
        )
    {
        SwapInfo storage swapInfo = swapInfos[_swapId];
        _recorderId = swapInfo.recorderId;
        _controller = swapInfo.controller;
        _originTokenSizeInByte = swapInfo.originTokenSizeInByte;
        _isBigEndian = swapInfo.isBigEndian;
        tokenList = swapInfo.tokenList;
    }

    function getSwapAmounts(bytes32 _swapId, bytes32 _uniqueId)
        external
        view
        returns (
            address _receiver,
            address[] memory _tokenList,
            uint256[] memory _receivedAmount
        )
    {
        SwapAmounts storage swapAmount = ledger[_swapId][_uniqueId];
        _receiver = swapAmount.receiver;
        _tokenList = swapInfos[_swapId].tokenList;
        _receivedAmount = new uint256[](_tokenList.length);
        for (uint256 i = 0; i < _tokenList.length; i++) {
            _receivedAmount[i] = swapAmount.receivedAmounts[_tokenList[i]];
        }
    }

    function computeLeafHash(
        uint256 _amount,
        bytes32 _uniqueId,
        SwapInfo storage _swapInfo,
        address _receiverAddress
    ) private view returns (bytes32) {
        bytes32 hashFromAmount =
            getHashTokenAmountData(
                _amount,
                _swapInfo.originTokenSizeInByte,
                _swapInfo.isBigEndian
            );
        bytes32 hashFromAddress = sha256(abi.encodePacked(_receiverAddress));
        return sha256(abi.encode(hashFromAmount, hashFromAddress, _uniqueId));
    }

    function getHashTokenAmountData(
        uint256 _amount,
        uint256 _originTokenSizeInByte,
        bool _isBigEndian
    ) public pure returns (bytes32) {
        bytes memory amountArray = new bytes(_originTokenSizeInByte);
        if (_isBigEndian) {
            uint256 i = _originTokenSizeInByte - 1;
            while (i >= 0) {
                amountArray[i] = bytes1(uint8(_amount));
                _amount = _amount >> 8;
                if (i == 0) {
                    break;
                }
                i--;
            }
        } else {
            uint256 i = 0;
            while (i < _originTokenSizeInByte) {
                amountArray[i] = bytes1(uint8(_amount));
                _amount = _amount >> 8;
                i++;
            }
        }
        return sha256(abi.encodePacked(amountArray));
    }

    function validtateSwapRatio(SwapRatio memory _swapRatio) private pure {
        require(
            _swapRatio.originShare > 0 && _swapRatio.targetShare > 0,
            "invalid swap ratio"
        );
    }

    function isOriginTokenSizeValid(uint256 _originTokenSizeInByte)
        private
        pure
        returns (bool)
    {
        if (
            _originTokenSizeInByte > maximalOriginTokenRangeSizeInByte ||
            _originTokenSizeInByte < minimalOriginTokenRangeSizeInByte
        ) {
            return false;
        }
        uint256 expectedSize = maximalOriginTokenRangeSizeInByte;
        while (expectedSize >= minimalOriginTokenRangeSizeInByte) {
            if (_originTokenSizeInByte == expectedSize) return true;
            expectedSize >>= 1;
        }
        return false;
    }

    function getSwapPair(bytes32 _swapId, address _token)
        private
        view
        returns (SwapPair storage)
    {
        require(swapInfos[_swapId].controller == msg.sender, "no permission");
        SwapPair storage swapPair = swapTargetTokenMap[_swapId][_token];
        require(swapPair.isUsed, "target token not registered");
        return swapPair;
    }
}
