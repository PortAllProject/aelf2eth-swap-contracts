const testContract = artifacts.require("TokenSwap");
const merkleTreeRecorderContract = artifacts.require("MerkleTreeRecorder");
const junContract = artifacts.require("JUNToken");
const cwContract = artifacts.require("CWToken");

contract('tokenSwap contract', (accounts) => {

    it('createSwap test', async () => {
        // merkle tree recorder contract
        const merkleTreeRecorderInstance = await merkleTreeRecorderContract.deployed();
        let maximalLeafCount = 8;
        await merkleTreeRecorderInstance.createRecorder(accounts[0], maximalLeafCount);

        const junInstance = await junContract.deployed();
        const cwInstance = await cwContract.deployed();
        const testInstance = await testContract.deployed();
        let user = accounts[0]; //"0x627306090abaB3A6e1400e9345bC60c78a8BEf57"
        let receiver = accounts[1]; //"0xf17f52151EbEF6C7334FAD080c5704D77216b732"

        // approve token
        let amount = 1000000000000;
        await junInstance.mint(user, amount);
        await junInstance.approve(testInstance.address, amount);
        await cwInstance.mint(user, amount);
        await cwInstance.approve(testInstance.address, amount);

        let recorderId = 0;
        let originTokenSizeInByte = 8;
        let isBigEndian = false;
        let tokenList = [junInstance.address, cwInstance.address];
        let junDepositAmount = 100000000000;
        let cwDepositAmount = 100000000000;
        let depositAmount = [junDepositAmount, cwDepositAmount];
        let swapRatio = [
            {
                "originShare": 1,
                "targetShare": 1
            },
            {
                "originShare": 100,
                "targetShare": 10
            },
        ]
        let userCwBalBefore = await cwInstance.balanceOf(user);
        let userJunBalBefore = await junInstance.balanceOf(user);
        await testInstance.createSwap(recorderId, originTokenSizeInByte, isBigEndian, tokenList, depositAmount, swapRatio, { from: user });
        let userCwBalAfter = await cwInstance.balanceOf(user);
        let userJunBalAfter = await junInstance.balanceOf(user);

        // token balance test
        assert.equal(userCwBalBefore - userCwBalAfter, cwDepositAmount, "wrong deposit token for cw");
        assert.equal(userJunBalBefore - userJunBalAfter, junDepositAmount, "wrong deposit token for jun");
        let tokenSwapBalForCw = await cwInstance.balanceOf(testInstance.address);
        assert.equal(tokenSwapBalForCw, cwDepositAmount, "wrong deposit token for cw on token swap");
        let tokenSwapBalForJun = await junInstance.balanceOf(testInstance.address);
        assert.equal(tokenSwapBalForJun, junDepositAmount, "wrong deposit token for jun on token swap");
        let swapPairAdded = (await testInstance.getPastEvents('SwapPairAdded'))[0].returnValues;
        let swapId = swapPairAdded.swapId;

        //test swap pair
        let swapPairForCw = await testInstance.swapTargetTokenMap(swapId, cwInstance.address);
        let swapPairForJun = await testInstance.swapTargetTokenMap(swapId, junInstance.address);
        assert.equal(swapPairForCw.depositAmount, cwDepositAmount, "wrong deposit token for cw");
        assert.equal(swapPairForJun.depositAmount, junDepositAmount, "wrong deposit token for jun");
        // var addressStr = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
        // var amount = 100000000;
        // var originSize = 8;
        // var isBigEndian = false;
        // var receiptId = 0;
        let merkleTreeRoot1 = "0x4d47f459ee3a563be2fe714ff047d81b68d2302a6a5a0092aaca147611c8f95d";
        await merkleTreeRecorderInstance.recordMerkleTree(0, 0, merkleTreeRoot1);

        let swapTotalAmountForJun = 0;
        let swapTotalAmountForCw = 0;
        let swapAmount = 100000000;
        let rightNodeHash = "0x9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";
        let receiverBalOfCwBefore = await cwInstance.balanceOf(receiver);
        let receiverBalOfJunBefore = await junInstance.balanceOf(receiver);
        await testInstance.swapToken(
            swapId, 
            swapAmount, 
            receiver, 
            {
                lastLeafIndex: 0,
                uniqueId: "0xaf5570f5a1810b7af78caf4bc70a660f0df51e42baf91d4de5b2328de0e83dfc",
                merkelTreePath: [rightNodeHash],
                isLeftNode: [false]
            }, 
            { 
                from: receiver 
            });
        let receiverBalOfCwAfter = await cwInstance.balanceOf(receiver);
        let receiverBalOfJunAfter = await junInstance.balanceOf(receiver);
        assert.equal(receiverBalOfCwAfter - receiverBalOfCwBefore, swapAmount/10, "cw bal is wrong after swap token");
        assert.equal(receiverBalOfJunAfter - receiverBalOfJunBefore, swapAmount, "jun bal is wrong after swap token"); 
        swapTotalAmountForJun += swapAmount;
        swapTotalAmountForCw += swapAmount/10;

        let merkleTreeRoot2 = "0x6a957d0755b815f722397786bcc2f430fc56740b997505d9f4062d0abf11438a";
        await merkleTreeRecorderInstance.recordMerkleTree(0, 7, merkleTreeRoot2);
        swapAmount = 50000000;
        receiverBalOfCwBefore = receiverBalOfCwAfter;
        receiverBalOfJunBefore = receiverBalOfJunAfter;
        await testInstance.swapToken(
            swapId, 
            swapAmount, 
            receiver, 
            {
                lastLeafIndex: 7,
                uniqueId: "0xaae89fc0f03e2959ae4d701a80cc3915918c950b159f6abb6c92c1433b1a8534",
                merkelTreePath: [rightNodeHash],
                isLeftNode: [false]
            }, 
            { 
                from: receiver 
            });
        receiverBalOfCwAfter = await cwInstance.balanceOf(receiver);
        receiverBalOfJunAfter = await junInstance.balanceOf(receiver);
        assert.equal(receiverBalOfCwAfter - receiverBalOfCwBefore, swapAmount/10, "cw bal is wrong after swap token");
        assert.equal(receiverBalOfJunAfter - receiverBalOfJunBefore, swapAmount, "jun bal is wrong after swap token");
        swapTotalAmountForJun += swapAmount;
        swapTotalAmountForCw += swapAmount/10;

        let merkleTreeRoot3 = "0x5152e5c8ef86e72b76ccb77dda15542c0b330c3485d7de56eab20a40cc5307b4";
        await merkleTreeRecorderInstance.recordMerkleTree(0, 8, merkleTreeRoot3);
        swapAmount = 250000000;
        receiverBalOfCwBefore = receiverBalOfCwAfter;
        receiverBalOfJunBefore = receiverBalOfJunAfter;
        await testInstance.swapToken(
            swapId, 
            swapAmount, 
            receiver, 
            {
                lastLeafIndex: 8,
                uniqueId: "0x6cc16abd70eefb90dc0ba0d14fb088630873b2c6ad943f7442356735984c35a3",
                merkelTreePath: [rightNodeHash],
                isLeftNode: [false]
            }, 
            { 
                from: receiver 
            });
        receiverBalOfCwAfter = await cwInstance.balanceOf(receiver);
        receiverBalOfJunAfter = await junInstance.balanceOf(receiver);
        assert.equal(receiverBalOfCwAfter - receiverBalOfCwBefore, swapAmount/10, "cw bal is wrong after swap token");
        assert.equal(receiverBalOfJunAfter - receiverBalOfJunBefore, swapAmount, "jun bal is wrong after swap token"); 
        swapTotalAmountForJun += swapAmount;
        swapTotalAmountForCw += swapAmount/10;

        swapPairForCw = await testInstance.swapTargetTokenMap(swapId, cwInstance.address);
        swapPairForJun = await testInstance.swapTargetTokenMap(swapId, junInstance.address);
        assert.equal(swapPairForJun.swappedAmount, swapTotalAmountForJun, "jun swapped amount is wrong"); 
        assert.equal(swapPairForCw.swappedAmount, swapTotalAmountForCw, "cw swapped amount is wrong"); 
        assert.equal(swapPairForJun.swappedTimes, 3, "jun swapped time is wrong"); 
        assert.equal(swapPairForCw.swappedTimes, 3, "cw swapped time is wrong"); 
        assert.equal(swapPairForJun.depositAmount.toNumber() + swapTotalAmountForJun, junDepositAmount, "jun deposit amount is wrong"); 
        assert.equal(swapPairForCw.depositAmount.toNumber() + swapTotalAmountForCw, cwDepositAmount, "cw deposit amount is wrong"); 
    })
})