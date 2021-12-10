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

    it('mints through manager', async () => {
        const tokenURI = 'cap';
        const tokenId = 4;
        const recipientA = accounts[0];
        const balanceABefore = await nftFactory.balanceOf(recipientA.address);

        const creatorMessagePrefix = "\x19Ethereum Signed Message:\n" + tokenURI.length;
        const creatorSignature = await creator.signMessage(tokenURI);

        const managerMessage = utils.defaultAbiCoder.encode(
            [ "address", "uint256", "string" ],
            [ recipientA.address, tokenId, tokenURI ]
        );
        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        await factoryManager.mintBatch(
            appID,
            [recipientA.address],
            [tokenId],
            [tokenURI],
            [creatorMessagePrefix],
            [creatorSignature],
            [managerSignature]
        );

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).equals(1);

        const tokenURIResult = await nftFactory.tokenURI(tokenId);
        expect(tokenURIResult).equals(tokenURI);
    });

    it('caps mint', async () => {
        const tokenURI = 'cap';
        const tokenId = 5;

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
            [ "address", "uint256", "string" ],
            [ recipientA.address, tokenId, tokenURI ]
        );
        const managerMessageHash = utils.keccak256(managerMessage);
        const managerSignature = await manager.signMessage(utils.arrayify(managerMessageHash));

        try {
            await factoryManager.mintBatch(
                appID,
                [recipientA.address],
                [tokenId],
                [tokenURI],
                [creatorMessagePrefix],
                [creatorSignature],
                [managerSignature]
            );
        }
        catch(e) {

        }

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).equals(0);
    });
});