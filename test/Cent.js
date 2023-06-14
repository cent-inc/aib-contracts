import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

import fs from 'fs';
const Cent = JSON.parse(fs.readFileSync('./build/Cent.json'));

use(solidity);

describe('Cent', () => {
    const [owner, minter, creator, rando, ...accounts] = new MockProvider().getWallets();
    let token = null;
    const nullAddr = '0x0000000000000000000000000000000000000000';

    it('creates a token contract', async () => {
        token = await deployContract(owner, Cent, [ owner.address, "Test", "TEST" ]);
        const name = await token.name();
        const symbol = await token.symbol();
        expect(name).to.equal("Test");
        expect(symbol).to.equal("TEST");
    });
    it('prevents rando from setting minter', async () => {
        await expect(token.connect(rando).setMinterEnabled(owner.address, true)).to.be.revertedWith('Ownable: caller is not the owner');
    });
    it('lets owner set minter', async () => {
        await token.connect(owner).setMinterEnabled(minter.address, true);
        const isEnabled = await token.getMinterEnabled(minter.address);
        expect(isEnabled).to.equal(true);
    });

    it('only lets the minter mint', async () => {
        await expect(token.connect(rando).onMint(creator.address, 1)).to.be.revertedWith('Caller is not a minter');
    });

    it('has correct initial balances', async () => {
        const creatorBalance = await token.balanceOf(creator.address);
        const ownerBalance = await token.balanceOf(owner.address);
        expect(creatorBalance).to.equal('0');
        expect(ownerBalance).to.equal(utils.parseEther('80000000').toString());
    });

    it('issues tokens from one mint successfully', async () => {
        await token.connect(minter).onMint(creator.address, 1);
        const creatorBalance = await token.balanceOf(creator.address);
        const ownerBalance = await token.balanceOf(owner.address);
        expect(ownerBalance).to.equal(utils.parseEther('80000050').toString());
        expect(creatorBalance).to.equal(utils.parseEther('100').toString());
        const NFTTotal = await token.getNFTTotal();
        expect(NFTTotal).to.equal(1);
    });

    it('issues tokens from remaining mints in first tranche successfully', async () => {
        await token.connect(minter).onMint(creator.address, 1_000_000);
        const creatorBalance = await token.balanceOf(creator.address);
        const ownerBalance = await token.balanceOf(owner.address);
        expect(creatorBalance).to.equal(utils.parseEther('100000010').toString());
        expect(ownerBalance).to.equal(utils.parseEther('130000005').toString());
        const NFTTotal = await token.getNFTTotal();
        expect(NFTTotal).to.equal(1_000_001);
    });

    it('issues tokens from the second and third tranche successfully', async () => {
        await token.connect(minter).onMint(creator.address, 100_000_000);
        const creatorBalance = await token.balanceOf(creator.address);
        const ownerBalance = await token.balanceOf(owner.address);
        expect(creatorBalance).to.equal(utils.parseEther('280000000').toString());
        expect(ownerBalance).to.equal(utils.parseEther('220000000').toString());
        const NFTTotal = await token.getNFTTotal();
        expect(NFTTotal).to.equal(101_000_001);
    });

    it('issues no tokens successfully', async () => {
        await token.connect(minter).onMint(creator.address, 1_000_000_000);
        const creatorBalance = await token.balanceOf(creator.address);
        const ownerBalance = await token.balanceOf(owner.address);
        expect(creatorBalance).to.equal(utils.parseEther('280000000').toString());
        expect(ownerBalance).to.equal(utils.parseEther('220000000').toString());
        const NFTTotal = await token.getNFTTotal();
        expect(NFTTotal).to.equal(1_101_000_001);
    });

    it('issues halfway through the second tranche successfully', async () => {
        token = await deployContract(owner, Cent, [ owner.address, "Test", "TEST" ]);
        await token.connect(owner).setMinterEnabled(minter.address, true);

        await token.connect(minter).onMint(creator.address, 5_500_000);
        const creatorBalance = await token.balanceOf(creator.address);
        const ownerBalance = await token.balanceOf(owner.address);
        expect(creatorBalance).to.equal(utils.parseEther('145000000').toString());
        expect(ownerBalance).to.equal(utils.parseEther('152500000').toString());
        const NFTTotal = await token.getNFTTotal();
        expect(NFTTotal).to.equal(5_500_000);
    });
});
