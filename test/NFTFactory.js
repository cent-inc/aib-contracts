import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import { toBuffer, keccak256 } from 'ethereumjs-util';
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
    let nftfactory;
    it('creates groups', async () => {
        creatorGroup = await deployContract(creator, Group, []);
        managerGroup = await deployContract(manager, Group, []);
    });

    it('creates factory', async () => {
        nftfactory = await deployContract(creator, NFTFactory, [creatorGroup.address, managerGroup.address]);
    });

    it('mints - directly', async () => {
        const recipientA = accounts[0];
        const recipientB = accounts[1];

        const balanceABefore = await nftfactory.balanceOf(recipientA.address);
        const balanceBBefore = await nftfactory.balanceOf(recipientB.address);

        await nftfactory.connect(creator).mintBatch(
            [ recipientA.address, recipientB.address, recipientB.address ],
            [ 1, 2, 3 ],
            [ 'foo', 'bar', 'baz' ]
        );

        const balanceA = await nftfactory.balanceOf(recipientA.address);
        const balanceB = await nftfactory.balanceOf(recipientB.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).to.equal(1);
        expect(balanceB.toNumber() - balanceBBefore.toNumber()).to.equal(2);

        const tokenURI1 = await nftfactory.tokenURI(1);
        const tokenURI2 = await nftfactory.tokenURI(2);
        const tokenURI3 = await nftfactory.tokenURI(3);

        expect(tokenURI1).to.equal('foo');
        expect(tokenURI2).to.equal('bar');
        expect(tokenURI3).to.equal('baz');
    });

    it('mints - managed', async () => {
        const tokenURI = 'bat';
        const tokenId = 4;
        const recipientA = accounts[0];
        const balanceABefore = await nftfactory.balanceOf(recipientA.address);

        const creatorMessage = utils.defaultAbiCoder.encode([ "string" ], [ tokenURI ]);
        const creatorMessageHash = keccak256(toBuffer(creatorMessage));
        const creatorSignature = creator.signMessage(toBuffer(creatorMessageHash));

        const managerMessage = utils.defaultAbiCoder.encode(
            [ "address", "uint256", "string" ],
            [ recipientA.address, tokenId, tokenURI ]
        );
        const managerMessageHash = keccak256(toBuffer(managerMessage));
        const managerSignature = manager.signMessage(toBuffer(managerMessageHash));

        await nftfactory.managedMintBatch(
            [recipientA.address],
            [tokenId],
            [tokenURI],
            [creatorSignature],
            [managerSignature]
        );

        const balanceA = await nftfactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).equals(1);

        const tokenURIResult = await nftfactory.tokenURI(tokenId);
        expect(tokenURIResult).equals(tokenURI);
    });
});