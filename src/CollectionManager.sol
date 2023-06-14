// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './CloneFactory.sol';
import './Collection.sol';
import './MetadataManager.sol';
import './BaseRelayRecipient.sol';
import './Group.sol';
import './Cent.sol';

pragma experimental ABIEncoderV2;

pragma solidity 0.6.12;

contract CollectionManager is BaseRelayRecipient, Group, CloneFactory, MetadataManager {
    string public override versionRecipient = "1";

    string private constant ERROR_INVALID_INPUTS = "CollectionManager: input length mismatch";

    address private baseCollection;

    address private token;

    mapping(string => address) private collectionAddresses;
    mapping(address => CollectionMetadata) private collectionMetadata;
    uint256 private constant MAX_ROYALTY = 10000; // 100%

    constructor(address _token) public {
        baseCollection = address(new Collection());
        token = _token;
    }

    struct CollectionMetadata {
        uint256 royalty;
        address contractOwner;
        string contractURI;
        string name;
        string symbol;
        bool mintEnded;
    }

    function mintBatch(
        string memory contractURI,
        address contractOwner,
        uint256 contractRoyalty,
        string memory contractName,
        string memory contractSymbol,
        string memory tokenURI,
        uint64 tokenSupplyCap,
        uint256[] memory tokenIDs,
        address[] memory tokenRecipients,
        bool eligible,
        bytes memory signature
    ) external {
        bytes32 message = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(
            contractURI,
            contractOwner,
            contractRoyalty,
            contractName,
            contractSymbol,
            tokenURI,
            tokenSupplyCap,
            tokenIDs,
            tokenRecipients,
            eligible,
            address(this)
        )));
        address signer = ECDSA.recover(message, signature);
        require(isMember(signer), "CollectionManager: Invalid manager address");

        address collectionAddress = _getCollectionAddress(contractURI);
        if (collectionAddress == address(0)) {
            require(contractRoyalty <= MAX_ROYALTY, "CollectionManager: Invalid royalty");
            collectionAddress = _createCollection(
                contractURI,
                contractOwner,
                contractRoyalty,
                contractName,
                contractSymbol
            );
        }

        require(!collectionMetadata[collectionAddress].mintEnded, "Minting ended");

        Collection(collectionAddress).mintBatch(
            tokenURI,
            tokenSupplyCap,
            tokenRecipients,
            tokenIDs
        );
        if (eligible) {
            Cent(token).onMint(contractOwner, tokenIDs.length);
        }
    }

    function capBatch(
        string[] memory contractURIs,
        bytes[] memory operatorSignatures
    ) external {
        require (
            contractURIs.length == operatorSignatures.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < contractURIs.length; ++i) {
            bytes32 operatorHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(contractURIs[i])));
            address operator = ECDSA.recover(operatorHash, operatorSignatures[i]);
            require(isMember(operator), "Collection: Invalid manager address");
            collectionMetadata[_getCollectionAddress(contractURIs[i])].mintEnded = true;
        }
    }

    function transferBatch(
        string[] memory contractURIs,
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        require (
            contractURIs.length == tos.length &&
            contractURIs.length == tokenIDs.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < contractURIs.length; ++i) {
            Collection(getCollectionAddress(contractURIs[i])).managedTransfer(
                _msgSender(),
                tos[i],
                tokenIDs[i]
            );
        }
    }

    function burnBatch(
        string[] memory contractURIs,
        uint256[] memory tokenIDs
    ) external {
        require (
            contractURIs.length == tokenIDs.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < contractURIs.length; ++i) {
            Collection(getCollectionAddress(contractURIs[i])).managedBurn(
                _msgSender(),
                tokenIDs[i]
            );
        }
    }

    function existsBatch(
        string[] memory contractURIs,
        uint256[] memory tokenIDs
    ) external view returns (bool[] memory) {
        require (
            contractURIs.length == tokenIDs.length,
            ERROR_INVALID_INPUTS
        );
        bool[] memory exists = new bool[](contractURIs.length);
        for (uint256 i = 0; i < contractURIs.length; ++i) {
            address collectionAddress = getCollectionAddress(contractURIs[i]);
            if (collectionAddress != address(0)) {
                exists[i] = Collection(collectionAddress).exists(tokenIDs[i]);
            }
        }
        return exists;
    }

    function isApprovedOrOwnerBatch(
        string[] memory contractURIs,
        uint256[] memory tokenIDs,
        address[] memory spenders
    ) external view returns (bool[] memory) {
        require(
            contractURIs.length == tokenIDs.length &&
            contractURIs.length == spenders.length,
            ERROR_INVALID_INPUTS
        );
        bool[] memory approvedOrOwner = new bool[](contractURIs.length);
        for (uint256 i = 0; i < contractURIs.length; ++i) {
            address collectionAddress = getCollectionAddress(contractURIs[i]);
            if (collectionAddress != address(0)) {
                approvedOrOwner[i] = Collection(collectionAddress).isApprovedOrOwner(spenders[i], tokenIDs[i]);
            }
        }
        return approvedOrOwner;
    }

    function getCollectionAddress(
        string memory contractURI
    ) public view returns (address) {
        address collectionAddress = _getCollectionAddress(contractURI);
        require(collectionAddress != address(0), "CollectionManager: Collection not found");
        return collectionAddress;
    }

    function getCollectionAddresses(
        string[] memory contractURIs
    ) external view returns (address[] memory) {
        address[] memory addresses = new address[](contractURIs.length);
        for (uint256 i = 0; i < contractURIs.length; i++) {
            addresses[i] = _getCollectionAddress(contractURIs[i]);
        }
        return addresses;
    }

    function _getCollectionAddress(
        string memory contractURI
    ) internal view returns (address) {
        return collectionAddresses[contractURI];
    }

    function _createCollection(
        string memory contractURI,
        address contractOwner,
        uint256 contractRoyalty,
        string memory contractName,
        string memory contractSymbol
    ) internal returns (address) {
        require(collectionAddresses[contractURI] == address(0), "CollectionManager: Collection Set");
        address collectionAddress = createClone(baseCollection);
        Collection(collectionAddress).init();
        collectionAddresses[contractURI] = collectionAddress;
        CollectionMetadata storage metadata = collectionMetadata[collectionAddress];
        metadata.royalty = contractRoyalty;
        metadata.contractOwner = contractOwner;
        metadata.contractURI = contractURI;
        metadata.name = contractName;
        metadata.symbol = contractSymbol;
        return collectionAddress;
    }

    /* -- IRelayRecipient override -- */
    function _msgSender(
    ) internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    /* -- IManager overrides -- */
    function getContractName(address collectionAddress) external view override returns (string memory) {
        return collectionMetadata[collectionAddress].name;
    }
    function getContractSymbol(address collectionAddress) external view override returns (string memory) {
        return collectionMetadata[collectionAddress].symbol;
    }
    function getContractRoyalty(address collectionAddress) external view override returns (uint256) {
        return collectionMetadata[collectionAddress].royalty;
    }
    function getContractOwner(address collectionAddress) external view override returns (address) {
        return collectionMetadata[collectionAddress].contractOwner;
    }
    function setContractOwner(address collectionAddress, address newOwner) external override {
        require(_msgSender() == collectionAddress, "Unable to update owner");
        collectionMetadata[collectionAddress].contractOwner = newOwner;
    }
}
