const testContract = artifacts.require("MerkleTreeRecorder");

contract('merkle tree recorder', (accounts) => {
    it('add recorder', async () =>{
        const testInstance = await testContract.deployed();
        let admin =  accounts[0];
        let maximalLeafCount = 8;
        await testInstance.createRecorder(admin, maximalLeafCount);
        let recorderCreatedEvent = (await testInstance.getPastEvents('RecorderCreated'))[0].returnValues;
        assert.equal(recorderCreatedEvent.admin, admin, "invalid record info");
        assert.equal(recorderCreatedEvent.maximalLeafCount, maximalLeafCount, "invalid record info");
        assert.equal(recorderCreatedEvent.recorderId, 0, "invalid record info");

        let currentRecorderCount = await testInstance.merkleTreeRecorderCount();
        assert.equal(currentRecorderCount, 1, "error recorder count");
        let recorderInfo = await testInstance.recorders(recorderCreatedEvent.recorderId);
        assert.equal(recorderInfo.admin, admin, "get error recoreder");
    });

    it('record satisfied merkle tree', async () =>{
        const testInstance = await testContract.deployed();
        const merkleTreeRoot1 = "0x688787d8ff144c502c7f5cffaafe2cc588d86079f9de88304c26b0cb99ce91c6";
        await testInstance.recordMerkleTree(0, 0, merkleTreeRoot1);
        let merkleTreeRecordedEvent = (await testInstance.getPastEvents('MerkleTreeRecorded'))[0].returnValues;
        assert.equal(merkleTreeRecordedEvent.recorderId, 0, "invalid MerkleTreeRecorded event info");
        assert.equal(merkleTreeRecordedEvent.lastLeafIndex, 0, "invalid MerkleTreeRecorded event info");
        let merkleTree = await testInstance.getMerkleTree(0,0);
        assert.equal(merkleTree.firstLeafIndex, 0, "first leadIndex shoule be 0");
        assert.equal(merkleTree.lastLeafIndex, 0, "last leadIndex shoule be 0");
        assert.equal(merkleTree.merkleTreeRoot, merkleTreeRoot1, "merkle tree root is not right");
        let satisfiedMerkleTreeCount = await testInstance.satisfiedMerkleTreeCount(0);
        assert.equal(satisfiedMerkleTreeCount, 0, "no satisfied merkle tree exist");
        let unsatisfiedMerkleTree = await testInstance.unSatisfiedMerkleTrees(0,0);
        assert.equal(unsatisfiedMerkleTree.merkleTreeRoot, merkleTreeRoot1, "unsatisfied merkle tree info is not right");
        const merkleTreeRoot2 = "0x70ba33708cbfb103f1a8e34afef333ba7dc021022b2d9aaa583aabb8058d8d67";

        try {
            await testInstance.recordMerkleTree(0, 8, merkleTreeRoot2, {from: accounts[1]});
            assert.fail("The transaction should have thrown an error");
        }
        catch (err) {
            assert.include(err.message, "not admin", "The error message should contain 'not admin'");
        }

        try {
            await testInstance.recordMerkleTree(0, 9, merkleTreeRoot2);
            assert.fail("The transaction should have thrown an error");
        }
        catch (err) {
            assert.include(err.message, "satisfied MerkleTree absent", "The error message should contain 'satisfied MerkleTree absent'");
        }
        try {
            await testInstance.recordMerkleTree(0, 8, merkleTreeRoot2);
            assert.fail("The transaction should have thrown an error");
        }
        catch (err) {
            assert.include(err.message, "unable to record the tree", "The error message should contain 'unable to record the tree'");
        }

        await testInstance.recordMerkleTree(0, 7, merkleTreeRoot2);
        let lastLeafIndex = await testInstance.getLastRecordedLeafIndex(0);
        assert.equal(lastLeafIndex, 7, "lastLeafIndex should be 6");
        unsatisfiedMerkleTree = await testInstance.satisfiedMerkleTrees(0,0);
        assert.equal(unsatisfiedMerkleTree.merkleTreeRoot, merkleTreeRoot2, "merkle tree root is not right");

        const merkleTreeRoot3 = "0xca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        await testInstance.recordMerkleTree(0, 8, merkleTreeRoot3);
        unsatisfiedMerkleTree = await testInstance.unSatisfiedMerkleTrees(0,0);
        assert.equal(unsatisfiedMerkleTree.merkleTreeRoot, merkleTreeRoot3, "unsatisfied merkle tree info is not right");
    });
});