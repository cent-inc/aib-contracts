// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/8e0296096449d9b1cd7c5631e917330635244c37
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Burnable.sol';
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './BaseRelayRecipient.sol';
import './Group.sol';

pragma experimental ABIEncoderV2;
pragma solidity >=0.4.22 <0.9.0;

contract NFTFactory is ERC721Burnable, BaseRelayRecipient {

    address public mintCreator;
    address public mintManager;

    constructor(address _mintCreator, address _mintManager) public ERC721("Tests", "TEST") {
        mintCreator = _mintCreator;
        mintManager = _mintManager;
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
    }

    /**
     * @dev creator mints directly to the contract
     *
     * @param tos address[] array of recipients to mint to
     * @param tokenIds uint256[] array of ids to key the tokens with
     * @param tokenURIs string[] array of metadata URIs for each token
     */
    function mintBatch(
        address[] memory tos,
        uint256[] memory tokenIds,
        string[] memory tokenURIs
    ) public {
        require(Group(mintCreator).isMember(_msgSender()), "NFTFactory: Invalid creator address");
        require(
            tos.length == tokenIds.length &&
            tos.length == tokenURIs.length,
            "NFTFactory: input length mismatch"
        );
        for (uint256 i = 0; i < tos.length; ++i) {
            _mint(tos[i], tokenIds[i]);
            _setTokenURI(tokenIds[i], tokenURIs[i]);
        }
    }

    function managedMintBatch(
        address[] memory tos,
        uint256[] memory tokenIds,
        string[] memory tokenURIs,
        bytes[] memory creatorSignatures,
        bytes[] memory managerSignatures
    ) public {
        require(
            tos.length == tokenIds.length &&
            tos.length == tokenURIs.length &&
            tos.length == creatorSignatures.length &&
            tos.length == managerSignatures.length,
            "NFTFactory: input length mismatch"
        );
        for (uint256 i = 0; i < tos.length; ++i) {
            bytes32 creatorHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(tokenURIs[i])));
            bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(tos[i], tokenIds[i], tokenURIs[i])));

            address creator = ECDSA.recover(creatorHash, creatorSignatures[i]);
            address manager = ECDSA.recover(managerHash, managerSignatures[i]);

            require(Group(mintCreator).isMember(creator), "NFTFactory: Invalid creator address");
            require(Group(mintManager).isMember(manager), "NFTFactory: Invalid manager address");

            _mint(tos[i], tokenIds[i]);
            _setTokenURI(tokenIds[i], tokenURIs[i]);
        }
    }

    function burnBatch(
        uint256[] memory tokenIds
    ) public {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            burn(tokenIds[i]);
        }
    }

    function approveBatch(
        address[] memory tos,
        uint256[] memory tokenIds
    ) public {
        require(tos.length == tokenIds.length, "NFTFactory: input length mismatch");
        for (uint256 i = 0; i < tos.length; ++i) {
            approve(tos[i], tokenIds[i]);
        }
    }

    function transferFromBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIds
    ) public {
        require(
            froms.length == tos.length &&
            froms.length == tokenIds.length,
            "NFTFactory: input length mismatch"
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            transferFrom(froms[i], tos[i], tokenIds[i]);
        }
    }

    function safeTransferFromBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIds
    ) public {
        require(
            froms.length == tos.length &&
            froms.length == tokenIds.length,
            "NFTFactory: input length mismatch"
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            safeTransferFrom(froms[i], tos[i], tokenIds[i], "");
        }
    }

    function safeTransferFromWithDataBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIds,
        bytes[] memory datas
    ) public {
        require(
            froms.length == tos.length &&
            froms.length == tokenIds.length &&
            froms.length == datas.length,
            "NFTFactory: input length mismatch"
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            safeTransferFrom(froms[i], tos[i], tokenIds[i], datas[i]);
        }
    }

    function isApprovedOrOwnerBatch(
        address[] memory spenders,
        uint256[] memory tokenIds
    ) public view returns (bool[] memory) {
        require(spenders.length == tokenIds.length, "NFTFactory: input length mismatch");
        bool[] memory approvals = new bool[](spenders.length);
        for (uint256 i = 0; i < spenders.length; ++i) {
            approvals[i] = _isApprovedOrOwner(spenders[i], tokenIds[i]);
        }
        return approvals;
    }

    function isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) public view returns (bool) {
        return _isApprovedOrOwner(spender, tokenId);
    }

    /* -- BEGIN IRelayRecipient overrides -- */
    function _msgSender() internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    string public override versionRecipient = "1";
    /* -- END IRelayRecipient overrides -- */
}
