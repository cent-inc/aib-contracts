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
    function managedMint(
        address to,
        uint256 tokenID,
        string memory tokenURI,
        string memory creatorMessagePrefix,
        bytes memory creatorSignature,
        bytes memory managerSignature
    ) external;

    function managedTransfer(
        address from,
        address to,
        uint256 tokenID
    ) external;

    function managedBurn(
        address from,
        uint256 tokenID
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
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
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
     * Convenience methods to avoid needing to add contract to relayer
     */

    function mintBatch(
        uint256 appID,
        address[] memory tos,
        uint256[] memory tokenIDs,
        string[] memory tokenURIs,
        string[] memory creatorMessagePrefixes,
        bytes[] memory creatorSignatures,
        bytes[] memory managerSignatures
    ) external {
        Factory factory = Factory(getNFTFactory(appID));
        for (uint256 i = 0; i < tos.length; ++i) {
            factory.managedMint(
                tos[i],
                tokenIDs[i],
                tokenURIs[i],
                creatorMessagePrefixes[i],
                creatorSignatures[i],
                managerSignatures[i]
            );
        }
    }

    function transferBatch(
        uint256[] memory appIDs,
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        for (uint256 i = 0; i < appIDs.length; ++i) {
            Factory(getNFTFactory(appIDs[i])).managedTransfer(
                _msgSender(),
                tos[i],
                tokenIDs[i]
            );
        }
    }

    function burnBatch(
        uint256[] memory appIDs,
        uint256[] memory tokenIDs
    ) external {
        for (uint256 i = 0; i < appIDs.length; ++i) {
            Factory(getNFTFactory(appIDs[i])).managedBurn(
                _msgSender(),
                tokenIDs[i]
            );
        }
    }

    string public override versionRecipient = "1";
}
