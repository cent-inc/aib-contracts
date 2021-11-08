const NFTFactory = artifacts.require('./NFTFactory.sol');
const Group = artifacts.require('./Group.sol');

contract('NFTFactory', (accounts) => {
    it('deploys', async () => {
        const group = await Group.new();
        const factory = await NFTFactory.new(group.address);
    });
});