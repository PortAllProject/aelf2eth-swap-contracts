const testContract = artifacts.require("TokenSwap");
const merkleTreeRecorderContract = artifacts.require("MerkleTreeRecorder");

contract('tokenSwap contract with AElf data', (accounts) => {
    it('merkle proof test', async () => {
        const merkleTreeRecorderInstance = await merkleTreeRecorderContract.deployed();
        const testInstance = await testContract.deployed();
        let maximalLeafCount = 1024;
        var fs = require('fs');
        var path = require("path");
        var files = fs.readdirSync(path.join(__dirname, "./testData"));
        var recorderId = 0;
        for(var m = 0; m < files.length; m ++)
        {
            await merkleTreeRecorderInstance.createRecorder(accounts[0], maximalLeafCount);
            var file = files[m];
            var aelfData = require(path.join(__dirname, "./testData/" + file));
            await merkleTreeRecorderInstance.recordMerkleTree(recorderId, maximalLeafCount - 1, aelfData.root);
            var receipts = aelfData.receipts;
            var isBigEndian = false;
            var originTokenSizeInByte = 8;
            for(var i = 0; i < receipts.length; i ++){
                var receipt = receipts[i];
                var leafHash = await testInstance.computeLeafHash(
                    receipt.receipt_amount, 
                    receipt.receipt_index_hash,
                    originTokenSizeInByte,
                    receipt.receipt_target_address,
                    isBigEndian);
                var merkleProof = await merkleTreeRecorderInstance.merkleProof(
                    recorderId,
                    receipt.receipt_index,
                    leafHash._leafHash,
                    receipt.receipts_path.receipt_path_hash,
                    receipt.receipts_path.receipt_path_isLeft
                )
                if(!merkleProof){
                    console.log("record id: " + recorderId + "  file name : " + file);
                    console.log("tree root :" + aelfData.root);
                    console.log("receipt info :");
                    console.log(receipt);
                    console.log("amount hash: " + leafHash._hashFromAmount);
                    console.log("address hash: " + leafHash._hashFromAddress);
                    console.log("leaf hash: " + leafHash._leafHash);
                    console.log("================================");
                }
            }
            recorderId ++;
        }
    })
})