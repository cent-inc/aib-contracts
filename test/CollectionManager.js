import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

// import Group from '../build/Group.json';
import fs from 'fs';
const CollectionManager = JSON.parse(fs.readFileSync('./build/CollectionManager.json'));
const Cent = JSON.parse(fs.readFileSync('./build/Cent.json'));
const Collection = JSON.parse(fs.readFileSync('./build/Collection.json'));

use(solidity);

describe('CollectionManager', () => {
    const tokenRoyalty = 10_00; // 10%
    const provider = new MockProvider({
        ganacheOptions: {
            gasLimit: 20_000_000
        }
    });
    const [creator, contractOwner, manager, newOwner, ...recipients] = provider.getWallets();
    let collectionManager;
    let collectionAddress;
    let collection;
    let token;
    const tokenIDs = [1, 2, 3, 4, 5];
    const contractRoyalty = 20_00;
    const contractName = 'Tests';
    const contractSymbol = 'TEST';
    const tokenSupplyCap = 6;
    const contractURI = 'ipfs://QmYVwMb9JaArFxR93ExtsZsWQ1QKUiWj7s6qyRtZ56LZUj';
    const tokenURIs = [
        'ipfs://FOOVwMb9JaArFxR93ExtsZsWQ1QKUiWj7s6qyRtZ56LZUj',
        'ipfs://BARVwMb9JaArFxR93ExtsZsWQ1QKUiWj7s6qyRtZ56LZUj',
        'ipfs://BAZVwMb9JaArFxR93ExtsZsWQ1QKUiWj7s6qyRtZ56LZUj',
    ];
    it('deploys CollectionManager', async () => {
        collectionManager = await deployContract(manager, CollectionManager, ['0x0000000000000000000000000000000000000000']);
    });

    it('creates Collection and mints', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "string",
                "uint64",
                "uint256[]",
                "address[]",
                "bool",
                "address"
            ],
            [
                contractURI,
                contractOwner.address,
                contractRoyalty,
                contractName,
                contractSymbol,
                tokenURIs[0],
                tokenSupplyCap,
                [tokenIDs[0]],
                [recipients[0].address],
                false,
                collectionManager.address
            ]
        );

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        const txn = await collectionManager.mintBatch(
            contractURI,
            contractOwner.address,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURIs[0],
            tokenSupplyCap,
            [tokenIDs[0]],
            [recipients[0].address],
            false,
            contractSignature,
        );

        console.log(txn.gasLimit.toNumber())

        collectionAddress = await collectionManager.getCollectionAddress(contractURI);

        collection = new Contract(collectionAddress, Collection.abi, provider);
        const name = await collection.name();
        const symbol = await collection.symbol();
        const supply = await collection.totalSupply();
        const owner = await collection.owner();
        const uri = await collection.tokenURI(tokenIDs[0]);

        expect(name).to.equal(contractName);
        expect(supply).to.equal(1);
        expect(symbol).to.equal(contractSymbol);
        expect(owner).to.equal(contractOwner.address);
        expect(uri).to.equal(tokenURIs[0]);
    });


    it('prevents duplicate minted tokens', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "string",
                "uint64",
                "uint256[]",
                "address[]",
                "bool",
                "address"
            ],
            [
                contractURI,
                contractOwner.address,
                contractRoyalty,
                contractName,
                contractSymbol,
                tokenURIs[0],
                tokenSupplyCap,
                [tokenIDs[0]],
                [recipients[0].address],
                false,
                collectionManager.address
            ]
        );

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        await expect(collectionManager.mintBatch(
            contractURI,
            contractOwner.address,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURIs[0],
            tokenSupplyCap,
            [tokenIDs[0]],
            [recipients[0].address],
            false,
            contractSignature,
        )).to.be.revertedWith('ERC721: token already minted');
    });


    it('mints multiple of the same token type', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "string",
                "uint64",
                "uint256[]",
                "address[]",
                "bool",
                "address"
            ],
            [
                contractURI,
                contractOwner.address,
                contractRoyalty,
                contractName,
                contractSymbol,
                tokenURIs[0],
                tokenSupplyCap,
                tokenIDs.slice(1),
                tokenIDs.slice(1).map((x, i) => recipients[i].address),
                false,
                collectionManager.address
            ]
        );

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        const txn = await collectionManager.mintBatch(
            contractURI,
            contractOwner.address,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURIs[0],
            tokenSupplyCap,
            tokenIDs.slice(1),
            tokenIDs.slice(1).map((x, i) => recipients[i].address),
            false,
            contractSignature,
        );
        const newTokenIDs = tokenIDs.slice(1);
        for (const tokenID of newTokenIDs) {
            const uri = await collection.tokenURI(tokenID);
            expect(uri).to.equal(tokenURIs[0]);
        }
        collection = new Contract(collectionAddress, Collection.abi, provider);
        const supply = await collection.totalSupply();
        expect(supply).to.equal(1 + tokenIDs.slice(1).length);

        console.log(tokenIDs.slice(1).length, txn.gasLimit.toNumber())
    });

    it('mints multiple of a different token type', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "string",
                "uint64",
                "uint256[]",
                "address[]",
                "bool",
                "address"
            ],
            [
                contractURI,
                contractOwner.address,
                contractRoyalty,
                contractName,
                contractSymbol,
                tokenURIs[1],
                tokenSupplyCap,
                [999, 1000],
                [recipients[0].address, recipients[1].address],
                false,
                collectionManager.address
            ]
        );

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        const txn = await collectionManager.mintBatch(
            contractURI,
            contractOwner.address,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURIs[1],
            tokenSupplyCap,
            [999, 1000],
            [recipients[0].address, recipients[1].address],
            false,
            contractSignature,
        );
        const newTokenIDs = [999, 1000];
        for (const tokenID of newTokenIDs) {
            const uri = await collection.tokenURI(tokenID);
            expect(uri).to.equal(tokenURIs[1]);
        }

        console.log(tokenIDs.slice(1).length, txn.gasLimit.toNumber())
    });

    it('fails to mint past the supply cap', async () => {
        const tokenIDs = [1001, 1002];
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "string",
                "uint64",
                "uint256[]",
                "address[]",
                "bool",
                "address"
            ],
            [
                contractURI,
                contractOwner.address,
                contractRoyalty,
                contractName,
                contractSymbol,
                tokenURIs[0],
                tokenSupplyCap,
                tokenIDs,
                tokenIDs.map((x, i) => recipients[i].address),
                false,
                collectionManager.address
            ]
        );

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        await expect(collectionManager.mintBatch(
            contractURI,
            contractOwner.address,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURIs[0],
            tokenSupplyCap,
            tokenIDs,
            tokenIDs.map((x, i) => recipients[i].address),
            false,
            contractSignature,
        )).to.be.revertedWith('Supply capped');
    });


    it('fails to cap with invalid signature', async () => {
        const capMessage = utils.defaultAbiCoder.encode(
            [
                "string"
            ],
            [
                contractURI
            ]
        );

        const capMsgHash = utils.keccak256(capMessage);
        const capSignature = await creator.signMessage(utils.arrayify(capMsgHash));
        await expect(collectionManager.capBatch(
            [contractURI],
            [capSignature]
        )).to.be.reverted;
    });

    it('caps token minting', async () => {
        const capMessage = utils.defaultAbiCoder.encode(
            [
                "string",
            ],
            [
                contractURI,
            ]
        );

        const capMsgHash = utils.keccak256(capMessage);
        const capSignature = await manager.signMessage(utils.arrayify(capMsgHash));
        await collectionManager.capBatch(
            [contractURI],
            [capSignature]
        );
    });

    it('fails to mint capped token', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "string",
                "uint64",
                "uint256[]",
                "address[]",
                "bool",
                "address"
            ],
            [
                contractURI,
                contractOwner.address,
                contractRoyalty,
                contractName,
                contractSymbol,
                tokenURIs[0],
                tokenSupplyCap,
                [tokenIDs[0]],
                [recipients[0].address],
                false,
                collectionManager.address
            ]
        );

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        await expect(collectionManager.mintBatch(
            contractURI,
            contractOwner.address,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURIs[0],
            tokenSupplyCap,
            [tokenIDs[0]],
            [recipients[0].address],
            false,
            contractSignature,
        )).to.be.revertedWith('Minting ended');

    });

    it('transfers ownership from the initial owner', async () => {
        const owner = await collection.owner();
        expect(owner).to.equal(contractOwner.address);
        await expect(collection.connect(manager).transferOwnership(newOwner.address)).to.be.reverted;
        await collection.connect(contractOwner).transferOwnership(newOwner.address);
        const changedOwner = await collection.owner();
        expect(changedOwner).to.equal(newOwner.address);
        await expect(collection.connect(creator).transferOwnership(creator.address)).to.be.reverted;
        await collection.connect(newOwner).transferOwnership(creator.address);
        const creatorOwner = await collection.owner();
        expect(creatorOwner).to.equal(creator.address);
    });

    it('deploys CollectionManager and Token and sets up token', async () => {
        token = await deployContract(manager, Cent, [ manager.address, "Test", "TEST"]);
        collectionManager = await deployContract(manager, CollectionManager, [token.address]);
        await token.connect(manager).setMinterEnabled(collectionManager.address, true);
    });

    it('creates Collection and mints', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "string",
                "uint64",
                "uint256[]",
                "address[]",
                "bool",
                "address"
            ],
            [
                contractURI,
                contractOwner.address,
                contractRoyalty,
                contractName,
                contractSymbol,
                tokenURIs[0],
                tokenSupplyCap,
                [tokenIDs[0], tokenIDs[1]],
                [recipients[0].address, recipients[1].address],
                true,
                collectionManager.address
            ]
        );

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        const txn = await collectionManager.mintBatch(
            contractURI,
            contractOwner.address,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURIs[0],
            tokenSupplyCap,
            [tokenIDs[0], tokenIDs[1]],
            [recipients[0].address, recipients[1].address],
            true,
            contractSignature,
        );

        console.log(txn.gasLimit.toNumber())

        collectionAddress = await collectionManager.getCollectionAddress(contractURI);

        collection = new Contract(collectionAddress, Collection.abi, provider);
        const name = await collection.name();
        const symbol = await collection.symbol();
        const owner = await collection.owner();
        const uri = await collection.tokenURI(tokenIDs[0]);
        const ownerBalance = await token.balanceOf(contractOwner.address);

        expect(name).to.equal(contractName);
        expect(symbol).to.equal(contractSymbol);
        expect(owner).to.equal(contractOwner.address);
        expect(uri).to.equal(tokenURIs[0]);
        expect(ownerBalance).to.equal(utils.parseEther('200').toString());
    });

});
