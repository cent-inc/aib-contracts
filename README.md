# aib-contracts

## How to use

`npm run build` to compile the contracts in the `src` directory

`npm run test` to run the tests in the `test` directory against that last build

`npm run flatten` to flatten the contracts (for source verification/deployment)

## Deployment process

1. Deploy the `NFTFactoryDeployer`

2. Deploy the `NFTFactoryManager(coldwallet, deployer)` with the group admin used in the aib-backend and the deployer just deployed

3. Call `NFTFactoryManager.getManagerGroup()`, initialize the `Group`, and add member used by backend
