// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './CloneFactory.sol';
import './NFTFactory.sol';
import './DefaultOwner.sol';
import './BaseRelayRecipient.sol';
import './Group.sol';

pragma experimental ABIEncoderV2;

pragma solidity 0.6.12;

contract NFTFactoryManager is BaseRelayRecipient, Group, CloneFactory, DefaultOwner {
    string public override versionRecipient = "1";

    string private constant ERROR_INVALID_INPUTS = "NFTFactoryManager: input length mismatch";

    address private baseFactory;
    address public defaultOwner;

    mapping(string => address) private factoryAddresses;
    mapping(string => address) private factoryOwners;

    constructor(
        address _defaultOwner
    ) public {
        defaultOwner = _defaultOwner;
        baseFactory = address(new NFTFactory());
    }

    function createFactory(
        string memory contractURI,
        address creatorAddress,
        address royaltyAddress,
        uint256 royaltyRate,
        string memory tokenName,
        string memory tokenSymbol,
        bytes memory managerSignature
    ) external {
        bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(
            contractURI,
            creatorAddress,
            royaltyAddress,
            royaltyRate,
            tokenName,
            tokenSymbol
        )));
        address signer = ECDSA.recover(managerHash, managerSignature);
        require(isMember(signer), "NFTFactoryManager: Invalid manager address");

        _createFactory(
            contractURI,
            creatorAddress,
            royaltyAddress,
            royaltyRate,
            tokenName,
            tokenSymbol
        );
    }

    /**
     * Convenience methods to avoid needing to add contract to relayer
     */
    function mintBatch(
        string[] memory contractURIs,
        address[] memory creatorAddresses,
        address[] memory royaltyAddresses,
        uint256[] memory royaltyRates,
        string[] memory tokenNames,
        string[] memory tokenSymbols,
        address[] memory tos,
        uint256[] memory tokenIDs,
        string[] memory tokenURIs,
        bytes[] memory creatorSignatures,
        bytes[] memory managerSignatures
    ) external {
        for (uint256 i = 0; i < tos.length; ++i) {
            bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(
                contractURIs[i],
                creatorAddresses[i],
                royaltyAddresses[i],
                royaltyRates[i],
                tokenNames[i],
                tokenSymbols[i],
                tos[i],
                tokenIDs[i],
                tokenURIs[i]
            )));
            address signer = ECDSA.recover(managerHash, managerSignatures[i]);
            require(isMember(signer), "NFTFactoryManager: Invalid manager address");

            address factoryAddress = _getFactoryAddress(contractURIs[i]);
            if (factoryAddress == address(0)) {
                factoryAddress = _createFactory(
                    contractURIs[i],
                    creatorAddresses[i],
                    royaltyAddresses[i],
                    royaltyRates[i],
                    tokenNames[i],
                    tokenSymbols[i]
                );
            }

            NFTFactory(factoryAddress).managedMint(
                tos[i],
                tokenIDs[i],
                tokenURIs[i],
                creatorSignatures[i]
            );
        }
    }

    function _createFactory(
        string memory contractURI,
        address creatorAddress,
        address royaltyAddress,
        uint256 royaltyRate,
        string memory tokenName,
        string memory tokenSymbol
    ) internal returns (address) {
        address factoryAddress = createClone(baseFactory);
        NFTFactory(factoryAddress).init(
            creatorAddress,
            royaltyAddress,
            royaltyRate,
            tokenName,
            tokenSymbol,
            contractURI
        );
        _setFactoryAddress(contractURI, factoryAddress);
        return factoryAddress;
    }


    function capBatch(
        string[] memory contractURIs,
        string[] memory tokenURIs,
        bytes[] memory managerSignatures
    ) external {
        require (
            contractURIs.length == tokenURIs.length &&
            contractURIs.length == managerSignatures.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < contractURIs.length; ++i) {
            bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(contractURIs[i], tokenURIs[i])));
            address manager = ECDSA.recover(managerHash, managerSignatures[i]);
            require(isMember(manager), "NFTFactory: Invalid manager address");
            NFTFactory(getFactoryAddress(contractURIs[i])).managedCap(
                tokenURIs[i]
            );
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
            NFTFactory(getFactoryAddress(contractURIs[i])).managedTransfer(
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
            NFTFactory(getFactoryAddress(contractURIs[i])).managedBurn(
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
            address factoryAddress = getFactoryAddress(contractURIs[i]);
            if (factoryAddress != address(0)) {
                exists[i] = NFTFactory(factoryAddress).exists(tokenIDs[i]);
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
            address factoryAddress = getFactoryAddress(contractURIs[i]);
            if (factoryAddress != address(0)) {
                approvedOrOwner[i] = NFTFactory(factoryAddress).isApprovedOrOwner(spenders[i], tokenIDs[i]);
            }
        }
        return approvedOrOwner;
    }

    function getFactoryAddress(
        string memory contractURI
    ) public view returns (address) {
        address nftFactory = _getFactoryAddress(contractURI);
        require(nftFactory != address(0), "NFTFactoryManager: NFTFactory not found");
        return nftFactory;
    }

    function getFactoryAddresses(
        string[] memory contractURIs
    ) external view returns (address[] memory) {
        address[] memory nftFactories = new address[](contractURIs.length);
        for (uint256 i = 0; i < contractURIs.length; i++) {
            nftFactories[i] = _getFactoryAddress(contractURIs[i]);
        }
        return nftFactories;
    }

    function getDefaultOwner(
    ) external override view returns (address) {
        return defaultOwner;
    }

    function setDefaultOwner(
        address newDefaultOwner
    ) external onlyAdmin {
        require(newDefaultOwner != address(0), "NFTFactoryManager: Invalid Owner Address");
        defaultOwner = newDefaultOwner;
    }

    function _getFactoryAddress(
        string memory contractURI
    ) internal view returns (address) {
        return factoryAddresses[contractURI];
    }

    function _setFactoryAddress(
        string memory contractURI,
        address contractAddress
    ) internal {
        require(factoryAddresses[contractURI] == address(0), "NFTFactoryManager: Factory Set");
        factoryAddresses[contractURI] = contractAddress;
    }

    /* -- IRelayRecipient override -- */
    function _msgSender(
    ) internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

}
