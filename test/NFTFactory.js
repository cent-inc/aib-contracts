import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

import fs from 'fs';
const NFTFactory = JSON.parse(fs.readFileSync('./build/NFTFactory.json'));

use(solidity);

describe('NFTFactory', () => {
    const tokenRoyalty = 1000; // 10%
    const maxRoyalty = 10000; // 100%
    const directTokenIDs = ["1000000000000000001", "1000000000000000002", "1000000000000000003"];
    const directTokenURIs = ["foo", "bar", "bar"];
    const contractURI = "contractURI";
    const [creator, manager, recipientA, recipientB, ...accounts] = new MockProvider().getWallets();
    let nftFactory;

    it('creates factory', async () => {
        nftFactory = await deployContract(manager, NFTFactory, []);
        await nftFactory.connect(manager).init(
            creator.address,
            creator.address,
            tokenRoyalty,
            "Tests",
            "TEST",
            "contractURI"
        );
    });

    it('mints three tokens, two with same uri', async () => {
        const balanceABefore = await nftFactory.balanceOf(recipientA.address);
        const balanceBBefore = await nftFactory.balanceOf(recipientB.address);

        const creatorSignatureA = await creator.signMessage("Collection: " + contractURI + "\n\nToken: " + directTokenURIs[0]);
        const creatorSignatureB = await creator.signMessage("Collection: " + contractURI + "\n\nToken: " + directTokenURIs[1]);
        const creatorSignatureC = await creator.signMessage("Collection: " + contractURI + "\n\nToken: " + directTokenURIs[2]);

        await nftFactory.connect(manager).managedMint(recipientA.address, directTokenIDs[0], directTokenURIs[0], creatorSignatureA);
        await nftFactory.connect(manager).managedMint(recipientA.address, directTokenIDs[1], directTokenURIs[1], creatorSignatureB);
        await nftFactory.connect(manager).managedMint(recipientB.address, directTokenIDs[2], directTokenURIs[2], creatorSignatureC);

        const balanceA = await nftFactory.balanceOf(recipientA.address);
        expect(balanceA.toNumber() - balanceABefore.toNumber()).equals(2);

        const balanceB = await nftFactory.balanceOf(recipientB.address);
        expect(balanceB.toNumber() - balanceBBefore.toNumber()).to.equal(1);

    });

    it('returns proper approvals for tokens', async () => {
        await nftFactory.connect(recipientB).approve(recipientA.address, directTokenIDs[2]);

        const approvalA0 = await nftFactory.isApprovedOrOwner(recipientA.address, directTokenIDs[0]);
        const approvalB0 = await nftFactory.isApprovedOrOwner(recipientB.address, directTokenIDs[0]);
        const approvalA2 = await nftFactory.isApprovedOrOwner(recipientA.address, directTokenIDs[2]);
        const approvalB2 = await nftFactory.isApprovedOrOwner(recipientB.address, directTokenIDs[2]);
        expect(approvalA0).to.equal(true);
        expect(approvalB0).to.equal(false);
        expect(approvalA2).to.equal(true);
        expect(approvalB2).to.equal(true);
    })

    it('returns the correct uris', async () => {
        const tokenURI1 = await nftFactory.tokenURI(directTokenIDs[0]);
        const tokenURI2 = await nftFactory.tokenURI(directTokenIDs[1]);
        const tokenURI3 = await nftFactory.tokenURI(directTokenIDs[2]);

        expect(tokenURI1).to.equal(directTokenURIs[0]);
        expect(tokenURI2).to.equal(directTokenURIs[1]);
        expect(tokenURI3).to.equal(directTokenURIs[2]);
    });

    it('reports on whether tokens exist', async () => {
        const exists0 = await nftFactory.exists(directTokenIDs[0]);
        const exists1 = await nftFactory.exists(directTokenIDs[1]);
        const exists2 = await nftFactory.exists(directTokenIDs[2]);
        const exists3 = await nftFactory.exists(1);
        expect(exists0).to.equal(true);
        expect(exists1).to.equal(true);
        expect(exists2).to.equal(true);
        expect(exists3).to.equal(false);
    });

    it('reports correct initial and transferred royalty amounts and receivers', async () => {
        const recipientA = accounts[0];
        const price = 1000;
        const [receiverA, royaltyA] = await nftFactory.royaltyInfo(directTokenIDs[0], price);
        expect(receiverA).to.equal(creator.address);
        expect(royaltyA.toNumber()).to.equal(price * tokenRoyalty / maxRoyalty);

        await expect(nftFactory.connect(creator).transferRoyalties(recipientA.address)).to.be.reverted;
        await nftFactory.connect(manager).transferOwnership(creator.address);
        await nftFactory.connect(creator).transferRoyalties(recipientA.address);
        const [newReceiverA, newRoyaltyA] = await nftFactory.royaltyInfo(directTokenIDs[0], price);
        expect(newReceiverA).to.equal(recipientA.address);
        expect(royaltyA.toNumber()).to.equal(price * tokenRoyalty / maxRoyalty);

    });

});
