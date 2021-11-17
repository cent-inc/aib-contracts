// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './BaseRelayRecipient.sol';
import './Group.sol';

pragma experimental ABIEncoderV2;

pragma solidity 0.6.12;

interface Deployer {
    function deploy(address creatorGroup, address managerGroup) external returns (address);
}

interface Factory {
    function managedMintBatch(
        address[] memory tos,
        uint256[] memory tokenIds,
        string[] memory tokenURIs,
        bytes[] memory creatorSignatures,
        bytes[] memory managerSignatures
    ) external;
}

contract NFTFactoryManager is BaseRelayRecipient {

    Group private managerGroup;
    Deployer private nftFactoryDeployer;

    mapping(uint256 => address) private creatorGroups;
    mapping(uint256 => address) private nftFactories;

    address private constant NULL_ADDRESS = 0x0000000000000000000000000000000000000000;

    constructor(address manager, address deployer) public {
        managerGroup = new Group(manager);
        nftFactoryDeployer = Deployer(deployer);
    }
    function createFactory(uint256 appID, address creator, bytes memory managerSignature) public {
        require(nftFactories[appID] == NULL_ADDRESS, "NFTFactoryManager: NFTFactory exists");

        bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(appID, creator)));
        address manager = ECDSA.recover(managerHash, managerSignature);
        require(managerGroup.isMember(manager), "NFTFactoryManager: Invalid manager address");

        Group creatorGroup = new Group(creator);

        address nftFactory = nftFactoryDeployer.deploy(address(creatorGroup), address(managerGroup));

        nftFactories[appID] = nftFactory;
        creatorGroups[appID] = address(creatorGroup);
    }

    function getManagerGroup() public view returns (address) {
        return address(managerGroup);
    }

    function getCreatorGroup(uint256 appID) public view returns (address) {
        address creatorGroup = creatorGroups[appID];
        require(creatorGroup != NULL_ADDRESS, "NFTFactoryManager: Group not found");
        return creatorGroup;
    }

    function getNFTFactory(uint256 appID) public view returns (address) {
        address nftFactory = nftFactories[appID];
        require(nftFactory != NULL_ADDRESS, "NFTFactoryManager: NFTFactory not found");
        return nftFactory;
    }

    /**
     * Convenience method to avoid needing to add contract to relayer
     */
    function managedMintBatch(
        uint256 appID,
        address[] memory tos,
        uint256[] memory tokenIDs,
        string[] memory tokenURIs,
        bytes[] memory creatorSignatures,
        bytes[] memory managerSignatures
    ) external {
        Factory(getNFTFactory(appID)).managedMintBatch(
            tos,
            tokenIDs,
            tokenURIs,
            creatorSignatures,
            managerSignatures
        );
    }

    string public override versionRecipient = "1";
}
