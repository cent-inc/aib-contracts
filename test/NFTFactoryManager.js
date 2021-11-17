import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import { toBuffer, keccak256 } from 'ethereumjs-util';
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
        const managerMessageHash = keccak256(toBuffer(managerMessage));
        const managerSignature = manager.signMessage(toBuffer(managerMessageHash));

        const txn = await factoryManager.createFactory(appID, creator.address, managerSignature);

        const nftFactoryAddress = await factoryManager.getNFTFactory(appID);

        nftFactory = new Contract(nftFactoryAddress, NFTFactory.abi, provider);
    });

    it('mints through manager', async () => {
        const tokenURI = 'bat';
        const tokenId = 4;
        const recipientA = accounts[0];
        const balanceABefore = await nftFactory.balanceOf(recipientA.address);

        const creatorMessage = utils.defaultAbiCoder.encode([ "string" ], [ tokenURI ]);
        const creatorMessageHash = keccak256(toBuffer(creatorMessage));
        const creatorSignature = creator.signMessage(toBuffer(creatorMessageHash));

        const managerMessage = utils.defaultAbiCoder.encode(
            [ "address", "uint256", "string" ],
            [ recipientA.address, tokenId, tokenURI ]
        );
        const managerMessageHash = keccak256(toBuffer(managerMessage));
        const managerSignature = manager.signMessage(toBuffer(managerMessageHash));

        await factoryManager.managedMintBatch(
            appID,
            [recipientA.address],
            [tokenId],
            [tokenURI],
            [creatorSignature],
            [managerSignature]
        );

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).equals(1);

        const tokenURIResult = await nftFactory.tokenURI(tokenId);
        expect(tokenURIResult).equals(tokenURI);
    });
});