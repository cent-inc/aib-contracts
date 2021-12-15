import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

import NFTFactory from '../build/NFTFactory.json';
import NFTFactoryDeployer from '../build/NFTFactoryDeployer.json';
import NFTFactoryManager from '../build/NFTFactoryManager.json';
import Group from '../build/Group.json';

use(solidity);

describe('NFTFactoryManager', () => {
    const tokenRoyalty = 1000; // 10%
    const provider = new MockProvider();
    const [creator, manager, ...accounts] = provider.getWallets();
    let appID = 1;
    let creatorGroup;
    let managerGroup;
    let factoryDeployer;
    let factoryManager;
    let nftFactory;

    it('deploys NFTFactoryDeployer', async () => {
        factoryDeployer = await deployContract(manager, NFTFactoryDeployer, []);
    });

    it('deploys NFTFactoryManager', async () => {
        factoryManager = await deployContract(manager, NFTFactoryManager, [ manager.address, factoryDeployer.address ]);
    });

    it('creates NFTFactory', async () => {
        const managerMessage = utils.defaultAbiCoder.encode([ "uint256", "address" ], [ appID, creator.address ]);
        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        const txn = await factoryManager.createFactory(appID, creator.address, managerSignature);

        const nftFactoryAddress = await factoryManager.getNFTFactory(appID);

        nftFactory = new Contract(nftFactoryAddress, NFTFactory.abi, provider);
    });

    it('prevents duplicate factory app ids', async () => {
        const managerMessage = utils.defaultAbiCoder.encode([ "uint256", "address" ], [ appID, creator.address ]);
        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        await expect(factoryManager.createFactory(appID, creator.address, managerSignature)).to.be.reverted;
    });

    it('mints through manager', async () => {
        const tokenURI = 'cap';
        const tokenID = 4;
        const recipientA = accounts[0];
        const balanceABefore = await nftFactory.balanceOf(recipientA.address);

        const creatorMessagePrefix = "\x19Ethereum Signed Message:\n" + tokenURI.length;
        const creatorSignature = await creator.signMessage(tokenURI);

        const managerMessage = utils.defaultAbiCoder.encode(
            [ "address", "uint256", "uint256", "string" ],
            [ recipientA.address, tokenID, tokenRoyalty, tokenURI ]
        );
        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        await factoryManager.mintBatch(
            [appID],
            [recipientA.address],
            [tokenID],
            [tokenRoyalty],
            [tokenURI],
            [creatorMessagePrefix],
            [creatorSignature],
            [managerSignature]
        );

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).to.equal(1);

        const tokenURIResult = await nftFactory.tokenURI(tokenID);
        expect(tokenURIResult).to.equal(tokenURI);
    });

    it('caps mint', async () => {
        const tokenURI = 'cap';
        const tokenID = 5;

        const capMessage = utils.defaultAbiCoder.encode(
            [ "string" ],
            [ tokenURI ]
        );
        const capMessageHash = utils.keccak256(capMessage);
        const capSignature = await  manager.signMessage(utils.arrayify(capMessageHash));
        await factoryManager.capBatch(
            [appID],
            [tokenURI],
            [capSignature]
        );


        const recipientA = accounts[0];
        const balanceABefore = await nftFactory.balanceOf(recipientA.address);

        const creatorMessagePrefix = "\x19Ethereum Signed Message:\n" + tokenURI.length;
        const creatorSignature = await creator.signMessage(tokenURI);

        const managerMessage = utils.defaultAbiCoder.encode(
            [ "address", "uint256", "uint256", "string" ],
            [ recipientA.address, tokenID, tokenRoyalty, tokenURI ]
        );
        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        await expect(factoryManager.mintBatch(
            [appID],
            [recipientA.address],
            [tokenID],
            [tokenRoyalty],
            [tokenURI],
            [creatorMessagePrefix],
            [creatorSignature],
            [managerSignature]
        )).to.be.reverted;

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).to.equal(0);
    });

    it('mints, burns, and transfers', async () => {
        const appIDs = [appID,appID,appID,appID,appID];
        const tokenURIs = ['a','a','a','a','a'];
        const tokenIDs = [10,11,12,13,14];
        const recipients = [accounts[3], accounts[3], accounts[3], accounts[4], accounts[4]];
        const royalties = [tokenRoyalty, tokenRoyalty, tokenRoyalty, tokenRoyalty, tokenRoyalty];
        const creatorMessagePrefixes = tokenIDs.map((tokenID, i) => ("\x19Ethereum Signed Message:\n" + tokenURIs[i].length));
        const creatorSignatures = [];
        for (const tokenURI of tokenURIs) {
            const creatorSignature = await creator.signMessage(tokenURI);
            creatorSignatures.push(creatorSignature);
        }

        const managerMessages = tokenIDs.map((tokenID, i) => utils.defaultAbiCoder.encode(
            [ "address", "uint256", "uint256", "string" ],
            [ recipients[i].address, tokenID, royalties[i], tokenURIs[i] ]
        ));
        const managerMessageHashes = managerMessages.map(m => utils.keccak256(m));
        const managerSignatures = [];
        for (const managerMessageHash of managerMessageHashes) {
            const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));
            managerSignatures.push(managerSignature);
        }

        const balanceBefore = await nftFactory.balanceOf(recipients[0].address);
        await factoryManager.mintBatch(
            appIDs,
            recipients.map(r => r.address),
            tokenIDs,
            royalties,
            tokenURIs,
            creatorMessagePrefixes,
            creatorSignatures,
            managerSignatures
        );
        expect(factoryManager.connect(recipients[0]).burnBatch(
            appIDs,
            tokenIDs
        )).to.be.reverted;
        const balanceAfterMint = await nftFactory.balanceOf(recipients[0].address);
        expect(balanceAfterMint.toNumber() - balanceBefore.toNumber()).to.equal(3);

        await factoryManager.connect(recipients[0]).burnBatch(appIDs.slice(0, 2), tokenIDs.slice(0, 2));
        const balanceAfterBurn = await nftFactory.balanceOf(recipients[0].address);
        expect(balanceAfterBurn.toNumber() - balanceAfterMint.toNumber()).to.equal(-2);

        await expect(factoryManager.connect(recipients[0]).transferBatch(
            appIDs.slice(2,4),
            [recipients[3].address, recipients[3].address],
            tokenIDs.slice(2,4)
        )).to.be.reverted;

        await factoryManager.connect(recipients[3]).transferBatch(
            appIDs.slice(3,5),
            [recipients[0].address, recipients[0].address],
            tokenIDs.slice(3,5)
        );
        const balanceAfterTransfer = await nftFactory.balanceOf(recipients[0].address);
        expect(balanceAfterTransfer.toNumber() - balanceAfterBurn.toNumber()).to.equal(2);
    });
});
