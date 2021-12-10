import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

import NFTFactory from '../build/NFTFactory.json';
import Group from '../build/Group.json';

use(solidity);

describe('NFTFactory', () => {
    const [creator, manager, ...accounts] = new MockProvider().getWallets();
    let creatorGroup;
    let managerGroup;
    let nftFactory;

    it('creates groups', async () => {
        creatorGroup = await deployContract(creator, Group, [ creator.address ]);
        managerGroup = await deployContract(manager, Group, [ manager.address ]);
    });

    it('creates factory', async () => {
        nftFactory = await deployContract(creator, NFTFactory, []);
        await nftFactory.init(creatorGroup.address, managerGroup.address, creator.address);
    });

    it('mints - directly', async () => {
        const recipientA = accounts[0];
        const recipientB = accounts[1];
        const tokenIDs = ["1000000000000000001", "1000000000000000002", "1000000000000000003"];

        const balanceABefore = await nftFactory.balanceOf(recipientA.address);
        const balanceBBefore = await nftFactory.balanceOf(recipientB.address);

        await nftFactory.connect(creator).mintBatch(
            [ recipientA.address, recipientB.address, recipientB.address ],
            [ 'foo', 'bar', 'baz' ]
        );

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        const balanceB = await nftFactory.balanceOf(recipientB.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).to.equal(1);
        expect(balanceB.toNumber() - balanceBBefore.toNumber()).to.equal(2);

        const tokenURI1 = await nftFactory.tokenURI(tokenIDs[0]);
        const tokenURI2 = await nftFactory.tokenURI(tokenIDs[1]);
        const tokenURI3 = await nftFactory.tokenURI(tokenIDs[2]);

        expect(tokenURI1).to.equal('foo');
        expect(tokenURI2).to.equal('bar');
        expect(tokenURI3).to.equal('baz');
    });

    it('mints - managed', async () => {
        const tokenURI = 'bat';
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

        await nftFactory.managedMint(
            recipientA.address,
            tokenId,
            tokenURI,
            creatorMessagePrefix,
            creatorSignature,
            managerSignature
        );

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).equals(1);

        const tokenURIResult = await nftFactory.tokenURI(tokenId);
        expect(tokenURIResult).equals(tokenURI);
    });
});