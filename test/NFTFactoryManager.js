import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

// import NFTFactory from '../build/NFTFactory.json';
// import NFTFactoryDeployer from '../build/NFTFactoryDeployer.json';
// import NFTFactoryManager from '../build/NFTFactoryManager.json';
// import Group from '../build/Group.json';
import fs from 'fs';
const NFTFactoryManager = JSON.parse(fs.readFileSync('./build/NFTFactoryManager.json'));
const NFTFactory = JSON.parse(fs.readFileSync('./build/NFTFactory.json'));

use(solidity);

describe('NFTFactoryManager', () => {
    const tokenRoyalty = 10_00; // 10%
    const provider = new MockProvider({
        ganacheOptions: {
            gasLimit: 20_000_000
        }
    });
    const [creator, royaltyReceiver, recipientA, recipientB, manager, defaultOwner, newOwner, ...accounts] = provider.getWallets();
    let factoryManager;
    let nftFactory;
    const tokenIDs = [1, 2, 3];
    const tokenName = 'Tests';
    const tokenSymbol = 'TEST';
    const contractURI = 'https://foo.com';
    const tokenURI = 'https://bar.com';
    const royaltyRate = 20_000;
    it('deploys NFTFactoryManager', async () => {
        factoryManager = await deployContract(manager, NFTFactoryManager, [defaultOwner.address]);
    });

    it('creates NFTFactory and mints', async () => {
        const managerMessage = utils.defaultAbiCoder.encode(
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
                tokenIDs[0],
                tokenURI
            ]
        );

        const creatorMessage = `Collection: ${contractURI}\n\nToken: ${tokenURI}`;
        const creatorSignature = await creator.signMessage(creatorMessage);

        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        const txn = await factoryManager.mintBatch(
            [contractURI],
            [creator.address],
            [royaltyReceiver.address],
            [royaltyRate],
            [tokenName],
            [tokenSymbol],
            [recipientA.address],
            [tokenIDs[0]],
            [tokenURI],
            [creatorSignature],
            [managerSignature]
        );
        console.log(txn.gasLimit.toNumber())

        const nftFactoryAddress = await factoryManager.getFactoryAddress(contractURI);

        nftFactory = new Contract(nftFactoryAddress, NFTFactory.abi, provider);
    });
    it('prevents duplicate minted tokens', async () => {
        const managerMessage = utils.defaultAbiCoder.encode(
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
                tokenIDs[0],
                tokenURI
            ]
        );

        const creatorMessage = `Collection: ${contractURI}\n\nToken: ${tokenURI}`;
        const creatorSignature = await creator.signMessage(creatorMessage);

        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        await expect(factoryManager.mintBatch(
            [contractURI],
            [creator.address],
            [royaltyReceiver.address],
            [royaltyRate],
            [tokenName],
            [tokenSymbol],
            [recipientA.address],
            [tokenIDs[0]],
            [tokenURI],
            [creatorSignature],
            [managerSignature]
        )).to.be.reverted;
    });

    it('mints multiple of the same token type', async () => {
        const managerMessage = utils.defaultAbiCoder.encode(
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
                tokenIDs[1],
                tokenURI
            ]
        );

        const creatorMessage = `Collection: ${contractURI}\n\nToken: ${tokenURI}`;
        const creatorSignature = await creator.signMessage(creatorMessage);

        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        const txn = await factoryManager.mintBatch(
            [contractURI],
            [creator.address],
            [royaltyReceiver.address],
            [royaltyRate],
            [tokenName],
            [tokenSymbol],
            [recipientA.address],
            [tokenIDs[1]],
            [tokenURI],
            [creatorSignature],
            [managerSignature]
        );
        console.log(txn.gasLimit.toNumber())
    });

    it('fails to cap with invalid signature', async () => {
        const managerMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "string"
            ],
            [
                contractURI,
                tokenURI
            ]
        );

        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await creator.signMessage(utils.arrayify(managerMessageHash));
        await expect(factoryManager.capBatch(
            [contractURI],
            [tokenURI],
            [managerSignature]
        )).to.be.reverted;
    });

    it('caps token minting', async () => {
        const managerMessage = utils.defaultAbiCoder.encode(
            [
                "string",
                "string"
            ],
            [
                contractURI,
                tokenURI
            ]
        );

        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));
        await factoryManager.capBatch(
            [contractURI],
            [tokenURI],
            [managerSignature]
        );
    });

    it('fails to mint capped token', async () => {
        const managerMessage = utils.defaultAbiCoder.encode(
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

        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        await expect(factoryManager.mintBatch(
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
            [managerSignature]
        )).to.be.reverted;
    });

    it('transfers ownership from the default owner', async () => {
        const owner = await nftFactory.owner();
        expect(owner).to.equal(defaultOwner.address);
        await expect(factoryManager.connect(defaultOwner).setDefaultOwner(newOwner.address)).to.be.reverted;
        await factoryManager.connect(manager).setDefaultOwner(newOwner.address);
        const changedOwner = await nftFactory.owner();
        expect(changedOwner).to.equal(newOwner.address);
        await expect(nftFactory.connect(creator).transferOwnership(creator.address)).to.be.reverted;
        await nftFactory.connect(newOwner).transferOwnership(creator.address);
        const creatorOwner = await nftFactory.owner();
        expect(creatorOwner).to.equal(creator.address);
    });
});
