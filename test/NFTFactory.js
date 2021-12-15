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
    const tokenRoyalty = 1000; // 10%
    const maxRoyalty = 10000; // 100%
    const directTokenIDs = ["1000000000000000001", "1000000000000000002", "1000000000000000003"];
    const [creator, manager, ...accounts] = new MockProvider().getWallets();
    let creatorGroup;
    let managerGroup;
    let nftFactory;

    it('creates groups', async () => {
        creatorGroup = await deployContract(creator, Group, [ ]);
        await creatorGroup.init(creator.address);
        managerGroup = await deployContract(manager, Group, [ ]);
        await managerGroup.init(manager.address);

        // Can't init twice
        await expect(managerGroup.init(manager.address)).to.be.reverted;

    });

    it('creates factory', async () => {
        nftFactory = await deployContract(creator, NFTFactory, []);
        await nftFactory.init(creatorGroup.address, managerGroup.address, creator.address);
    });

    it('mints - directly', async () => {
        const recipientA = accounts[0];
        const recipientB = accounts[1];

        const balanceABefore = await nftFactory.balanceOf(recipientA.address);
        const balanceBBefore = await nftFactory.balanceOf(recipientB.address);

        await nftFactory.connect(creator).mintBatch(
            [ recipientA.address, recipientB.address, recipientB.address ],
            [ tokenRoyalty, tokenRoyalty * 2, tokenRoyalty * 3 ],
            [ 'foo', 'bar', 'baz' ]
        );

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        const balanceB = await nftFactory.balanceOf(recipientB.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).to.equal(1);
        expect(balanceB.toNumber() - balanceBBefore.toNumber()).to.equal(2);

        await nftFactory.connect(recipientB).approve(recipientA.address, directTokenIDs[1]);
        const isApprovedOrOwners = await nftFactory.isApprovedOrOwnerBatch(
            [recipientA.address, recipientB.address, recipientA.address, recipientB.address],
            [directTokenIDs[0], directTokenIDs[0], directTokenIDs[1], directTokenIDs[1]]
        );
        expect(isApprovedOrOwners[0]).to.equal(true);
        expect(isApprovedOrOwners[1]).to.equal(false);
        expect(isApprovedOrOwners[2]).to.equal(true);
        expect(isApprovedOrOwners[3]).to.equal(true);
    });

    it('returns the correct uris', async () => {
        const tokenURI1 = await nftFactory.tokenURI(directTokenIDs[0]);
        const tokenURI2 = await nftFactory.tokenURI(directTokenIDs[1]);
        const tokenURI3 = await nftFactory.tokenURI(directTokenIDs[2]);

        expect(tokenURI1).to.equal('foo');
        expect(tokenURI2).to.equal('bar');
        expect(tokenURI3).to.equal('baz');
    });

    it('reports on whether tokens exist', async () => {
        const exists = await nftFactory.existsBatch(directTokenIDs.concat(12345));
        expect(exists[0]).to.equal(true);
        expect(exists[1]).to.equal(true);
        expect(exists[2]).to.equal(true);
        expect(exists[3]).to.equal(false);
    });

    it('reports amounts and receivers and updates', async () => {
        const recipientA = accounts[0];
        const recipientB = accounts[1];
        const price = 1000;
        const [receiverA, royaltyA] = await nftFactory.royaltyInfo(directTokenIDs[0], price);

        await expect(nftFactory.connect(recipientA).changeRoyaltyReceiver(recipientA.address)).to.be.reverted;

        const [receiverB, royaltyB] = await nftFactory.royaltyInfo(directTokenIDs[1], price);
        await nftFactory.changeRoyaltyReceiver(recipientA.address);
        const [receiverC, royaltyC] = await nftFactory.royaltyInfo(directTokenIDs[2], price);
        expect(receiverA).to.equal(creator.address);
        expect(receiverB).to.equal(creator.address);
        expect(receiverC).to.equal(recipientA.address);
        expect(royaltyA.toNumber()).to.equal(price * tokenRoyalty / maxRoyalty);
        expect(royaltyB.toNumber()).to.equal(price * 2 * tokenRoyalty / maxRoyalty);
        expect(royaltyC.toNumber()).to.equal(price * 3 * tokenRoyalty / maxRoyalty);
    });

    it('mints - managed', async () => {
        const tokenURI = 'bat';
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

        await nftFactory.managedMint(
            recipientA.address,
            tokenID,
            tokenRoyalty,
            tokenURI,
            creatorMessagePrefix,
            creatorSignature,
            managerSignature
        );

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).equals(1);

        const tokenURIResult = await nftFactory.tokenURI(tokenID);
        expect(tokenURIResult).equals(tokenURI);
    });
});
