import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

import fs from 'fs';
const Group = JSON.parse(fs.readFileSync('./build/Group.json'));

use(solidity);

describe('Group', () => {
    const [creator, ...accounts] = new MockProvider().getWallets();
    let group = null;
    const nullAddr = '0x0000000000000000000000000000000000000000';

    it('creates a group', async () => {
        group = await deployContract(creator, Group, [ ]);
    });
    it('recognizes admin', async () => {
        const admin = await group.getAdmin();
        expect(admin).to.equal(creator.address);
    });
    it('regognizes admin as member', async () => {
        const isMember = await group.isMember(accounts[0].address);
        expect(isMember).to.equal(false);
    });

    it('doesnt count non-member as member', async () => {
        const isMember = await group.isMember(accounts[0].address);
        expect(isMember).to.equal(false);
    });

    it('doesnt let anon nominate new admin', async () => {
        await expect(group.connect(accounts[0]).nominateAdmin(accounts[0].address)).to.be.reverted;;
        const currentNominee = await group.getNominee();
        expect(currentNominee).to.equal(nullAddr);
    });

    it('lets admin nominate new admin', async () => {
        await group.nominateAdmin(accounts[0].address);
        const currentNominee = await group.getNominee();
        expect(currentNominee).to.equal(accounts[0].address);
    });

    it('lets nominee accept admin and clears nominee', async () => {
        await group.connect(accounts[0]).acceptAdmin();
        const currentAdmin = await group.getAdmin();
        expect(currentAdmin).to.equal(accounts[0].address);
        const currentNominee = await group.getNominee();
        expect(currentNominee).to.equal(nullAddr);
        const isMember = await group.isMember(creator.address);
        expect(isMember).to.equal(false);
    });
});