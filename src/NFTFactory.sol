// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/8e0296096449d9b1cd7c5631e917330635244c37
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Burnable.sol';
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './BaseRelayRecipient.sol';
import './Group.sol';

pragma experimental ABIEncoderV2;
pragma solidity >=0.4.22 <0.9.0;

contract NFTFactory is ERC721Burnable, BaseRelayRecipient {

    string private constant ERROR_INVALID_INPUTS = "NFTFactory: input length mismatch";

    address public creatorGroup;
    address public managerGroup;

    constructor(address _creatorGroup, address _managerGroup) public ERC721("NFTs", "NFT") {
        creatorGroup = _creatorGroup;
        managerGroup = _managerGroup;
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
    }

    /**
     * @dev creator mints directly to the contract
     *
     * @param tos address[] array of recipients to mint to
     * @param tokenIDs uint256[] array of ids to key the tokens with
     * @param tokenURIs string[] array of metadata URIs for each token
     */
    function mintBatch(
        address[] memory tos,
        uint256[] memory tokenIDs,
        string[] memory tokenURIs
    ) external {
        require(Group(creatorGroup).isMember(_msgSender()), "NFTFactory: Invalid creator address");
        require(
            tos.length == tokenIDs.length &&
            tos.length == tokenURIs.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < tos.length; ++i) {
            _mint(tos[i], tokenIDs[i]);
            _setTokenURI(tokenIDs[i], tokenURIs[i]);
        }
    }

    function managedMintBatch(
        address[] memory tos,
        uint256[] memory tokenIDs,
        string[] memory tokenURIs,
        bytes[] memory creatorSignatures,
        bytes[] memory managerSignatures
    ) external {
        require(
            tos.length == tokenIDs.length &&
            tos.length == tokenURIs.length &&
            tos.length == creatorSignatures.length &&
            tos.length == managerSignatures.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < tos.length; ++i) {
            bytes32 creatorHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(tokenURIs[i])));
            bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(tos[i], tokenIDs[i], tokenURIs[i])));

            address creator = ECDSA.recover(creatorHash, creatorSignatures[i]);
            address manager = ECDSA.recover(managerHash, managerSignatures[i]);

            require(Group(creatorGroup).isMember(creator), "NFTFactory: Invalid creator address");
            require(Group(managerGroup).isMember(manager), "NFTFactory: Invalid manager address");

            _mint(tos[i], tokenIDs[i]);
            _setTokenURI(tokenIDs[i], tokenURIs[i]);
        }
    }

    function burnBatch(
        uint256[] memory tokenIDs
    ) external {
        for (uint256 i = 0; i < tokenIDs.length; ++i) {
            burn(tokenIDs[i]);
        }
    }

    function approveBatch(
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        require(tos.length == tokenIDs.length, ERROR_INVALID_INPUTS);
        for (uint256 i = 0; i < tos.length; ++i) {
            approve(tos[i], tokenIDs[i]);
        }
    }

    function transferFromBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        require(
            froms.length == tos.length &&
            froms.length == tokenIDs.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            transferFrom(froms[i], tos[i], tokenIDs[i]);
        }
    }

    function safeTransferFromBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        require(
            froms.length == tos.length &&
            froms.length == tokenIDs.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            safeTransferFrom(froms[i], tos[i], tokenIDs[i], "");
        }
    }

    function safeTransferFromWithDataBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIDs,
        bytes[] memory datas
    ) external {
        require(
            froms.length == tos.length &&
            froms.length == tokenIDs.length &&
            froms.length == datas.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            safeTransferFrom(froms[i], tos[i], tokenIDs[i], datas[i]);
        }
    }

    function isApprovedOrOwnerBatch(
        address[] memory spenders,
        uint256[] memory tokenIDs
    ) external view returns (bool[] memory) {
        require(spenders.length == tokenIDs.length, ERROR_INVALID_INPUTS);
        bool[] memory approvals = new bool[](spenders.length);
        for (uint256 i = 0; i < spenders.length; ++i) {
            approvals[i] = _isApprovedOrOwner(spenders[i], tokenIDs[i]);
        }
        return approvals;
    }

    function isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenId);
    }

    function existsBatch(
        uint256[] memory tokenIDs
    ) external view returns (bool[] memory) {
        bool[] memory exists = new bool[](tokenIDs.length);
        for (uint256 i = 0; i < tokenIDs.length; ++i) {
            exists[i] = _exists(tokenIDs[i]);
        }
        return exists;
    }

    /* -- BEGIN IRelayRecipient overrides -- */
    function _msgSender() internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    string public override versionRecipient = "1";
    /* -- END IRelayRecipient overrides -- */
}
