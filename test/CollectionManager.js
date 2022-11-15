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
const Collection = JSON.parse(fs.readFileSync('./build/Collection.json'));

use(solidity);

describe('CollectionManager', () => {
    const tokenRoyalty = 10_00; // 10%
    const provider = new MockProvider({
        ganacheOptions: {
            gasLimit: 20_000_000
        }
    });
    const [creator, royaltyReceiver, recipientA, recipientB, manager, newOwner, ...accounts] = provider.getWallets();
    let collectionManager;
    let collectionAddress;
    let collection;
    const tokenIDs = [1, 2, 3];
    const tokenName = 'Tests';
    const tokenSymbol = 'TEST';
    const tokenSupplyCap = 10;
    const contractURI = 'ipfs://QmYVwMb9JaArFxR93ExtsZsWQ1QKUiWj7s6qyRtZ56LZUj';
    const tokenURI = 'https://bar.com';
    const royaltyRate = 20_00;
    it('deploys CollectionManager', async () => {
        collectionManager = await deployContract(manager, CollectionManager, []);
    });


    it('creates Collection and mints', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "uint256"
            ],
            [
                contractURI,
                royaltyReceiver.address,
                royaltyRate,
                tokenName,
                tokenSymbol,
                tokenSupplyCap
            ]
        );

        const tokenMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "string",
                "uint256",
                "address"
            ],
            [
                contractURI,
                tokenURI,
                tokenIDs[0],
                recipientA.address
            ]
        );
        const tokenMsgHash = utils.keccak256(tokenMessage);
        const tokenSignature = await manager.signMessage(utils.arrayify(tokenMsgHash));

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        const txn = await collectionManager.mintBatch(
            [contractURI],
            [royaltyReceiver.address],
            [royaltyRate],
            [tokenName],
            [tokenSymbol],
            [tokenSupplyCap],
            [contractSignature],
            [tokenURI],
            [tokenIDs[0]],
            [recipientA.address],
            [tokenSignature],
        );

        console.log(txn.gasLimit.toNumber())

        collectionAddress = await collectionManager.getCollectionAddress(contractURI);

        collection = new Contract(collectionAddress, Collection.abi, provider);
        const contractName = await collectionManager.getContractName(collectionAddress);
        const contractSymbol = await collectionManager.getContractSymbol(collectionAddress);
        const contractRoyalty = await collectionManager.getContractRoyalty(collectionAddress);
        const contractOwner = await collectionManager.getContractOwner(collectionAddress);
        console.log(contractName);
        console.log(contractSymbol);
        console.log(contractRoyalty);
        console.log(contractOwner);
    });
    it('prevents duplicate minted tokens', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "uint256"
            ],
            [
                contractURI,
                royaltyReceiver.address,
                royaltyRate,
                tokenName,
                tokenSymbol,
                tokenSupplyCap
            ]
        );

        const tokenMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "string",
                "uint256",
                "address"
            ],
            [
                contractURI,
                tokenURI,
                tokenIDs[0],
                recipientA.address
            ]
        );
        const tokenMsgHash = utils.keccak256(tokenMessage);
        const tokenSignature = await manager.signMessage(utils.arrayify(tokenMsgHash));

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        await expect(collectionManager.mintBatch(
            [contractURI],
            [royaltyReceiver.address],
            [royaltyRate],
            [tokenName],
            [tokenSymbol],
            [tokenSupplyCap],
            [contractSignature],
            [tokenURI],
            [tokenIDs[0]],
            [recipientA.address],
            [tokenSignature],
        )).to.be.reverted;
    });

    it('mints multiple of the same token type', async () => {
        const contractMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "uint256",
                "string",
                "string",
                "uint256"
            ],
            [
                contractURI,
                royaltyReceiver.address,
                royaltyRate,
                tokenName,
                tokenSymbol,
                tokenSupplyCap
            ]
        );

        const tokenMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "string",
                "uint256",
                "address"
            ],
            [
                contractURI,
                tokenURI,
                tokenIDs[1],
                recipientA.address
            ]
        );
        console.log(manager.address);
        const tokenMsgHash = utils.keccak256(tokenMessage);
        const tokenSignature = await manager.signMessage(utils.arrayify(tokenMsgHash));

        const contractMsgHash = utils.keccak256(contractMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        const txn = await collectionManager.mintBatch(
            [contractURI],
            [royaltyReceiver.address],
            [royaltyRate],
            [tokenName],
            [tokenSymbol],
            [tokenSupplyCap],
            [contractSignature],
            [tokenURI],
            [tokenIDs[1]],
            [recipientA.address],
            [tokenSignature],
        );
        console.log(txn.gasLimit.toNumber())
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
        const contractSigMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "address",
                "address",
                "uint256",
                "string",
                "string",
                "address",
                "uint256",
                "string"
            ],
            [
                contractURI,
                creator.address,
                royaltyReceiver.address,
                royaltyRate,
                tokenName,
                tokenSymbol,
                recipientA.address,
                tokenIDs[2],
                tokenURI
            ]
        );

        const creatorMessage = `Collection: ${contractURI}\n\nToken: ${tokenURI}`;
        const creatorSignature = await creator.signMessage(creatorMessage);

        const contractMsgHash = utils.keccak256(contractSigMessage);
        const contractSignature = await manager.signMessage(utils.arrayify(contractMsgHash));

        await expect(collectionManager.mintBatch(
            [contractURI],
            [creator.address],
            [royaltyReceiver.address],
            [royaltyRate],
            [tokenName],
            [tokenSymbol],
            [recipientA.address],
            [tokenIDs[2]],
            [tokenURI],
            [creatorSignature],
            [contractSignature]
        )).to.be.reverted;
    });

    it('transfers ownership from the initial owner', async () => {
        const owner = await collection.owner();
        expect(owner).to.equal(royaltyReceiver.address);
        await expect(collection.connect(manager).transferOwnership(newOwner.address)).to.be.reverted;
        await collection.connect(royaltyReceiver).transferOwnership(newOwner.address);
        const changedOwner = await collection.owner();
        expect(changedOwner).to.equal(newOwner.address);
        await expect(collection.connect(creator).transferOwnership(creator.address)).to.be.reverted;
        await collection.connect(newOwner).transferOwnership(creator.address);
        const creatorOwner = await collection.owner();
        expect(creatorOwner).to.equal(creator.address);
    });
});
