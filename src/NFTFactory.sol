// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/8e0296096449d9b1cd7c5631e917330635244c37
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Burnable.sol';
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './IERC2981.sol';
import './BaseRelayRecipient.sol';
import './Group.sol';

pragma experimental ABIEncoderV2;
pragma solidity 0.6.12;

contract NFTFactory is ERC721Burnable, BaseRelayRecipient, IERC2981 {

    string private constant ERROR_INVALID_INPUTS = "NFTFactory: input length mismatch";

    mapping(uint256 => uint256) private royaltyAmounts;
    uint256 public constant MAX_ROYALTY = 10000; // 100%
    address public royaltyReceiver;

    address public creatorGroup;
    address public managerGroup;
    address public setupManager;

    bool private initialized;

    mapping(string => bool) public managedMintCapped;

    uint256 private constant directMintRangeStart = 1000000000000000001;
    uint256 private directMintOffset = 0;

    constructor() public ERC721("NFTs", "NFT") { }

    // Because we use a `CloneFactory`,
    // we must move any logic into the `init` method if possible
    // and override any other methods if not possible.
    function name() public view override returns (string memory) { return "NFTs"; }
    function symbol() public view override returns (string memory) { return "NFT"; }

    // Yanked from Zeppelin 721 since we don't have a constructor
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    function init(address _creatorGroup, address _managerGroup, address _setupManager) public {
        require(initialized == false, "NFTFactory: Already initialized");

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
        _registerInterface(_INTERFACE_ID_ERC2981);

        // hardcode the trusted forwarded for EIP2771 metatransactions
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);

        royaltyReceiver = Group(_creatorGroup).getAdmin();

        // hardcode the management of this contract
        creatorGroup = _creatorGroup;
        managerGroup = _managerGroup;
        setupManager = _setupManager;

        initialized = true;
    }

    // Mintanager from minting more a tokenURI
    function managedMint(
        address to,
        uint256 tokenID,
        uint256 tokenRoyalty,
        string memory tokenURI,
        string memory creatorMessagePrefix,
        bytes memory creatorSignature,
        bytes memory managerSignature
    ) external {
        require(managedMintCapped[tokenURI] == false, "NFTFactory: Managed mint capped");
        require(tokenID < directMintRangeStart, "NFTFactory: Token ID out of range");

        bytes32 creatorHash = keccak256(abi.encodePacked(creatorMessagePrefix, tokenURI));
        bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(to, tokenID, tokenRoyalty, tokenURI)));

        address creator = ECDSA.recover(creatorHash, creatorSignature);
        address manager = ECDSA.recover(managerHash, managerSignature);

        require(Group(creatorGroup).isMember(creator), "NFTFactory: Invalid creator address");
        require(Group(managerGroup).isMember(manager), "NFTFactory: Invalid manager address");

        _mint(to, tokenID);
        _setTokenRoyalty(tokenID, tokenRoyalty);
        _setTokenURI(tokenID, tokenURI);
    }

    // Prevent the group manager from minting more a tokenURI
    function managedCap(
        string memory tokenURI,
        bytes memory managerSignature
    ) external {
        bytes32 managerHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(tokenURI)));
        address manager = ECDSA.recover(managerHash, managerSignature);
        require(Group(managerGroup).isMember(manager), "NFTFactory: Invalid manager address");
        managedMintCapped[tokenURI] = true;
    }

    // Convenience method for easy transfers via NFTFactoryManager
    // Factory Manager must pass _msgSender() in `from` param
    function managedTransfer(
        address from,
        address to,
        uint256 tokenID
    ) external {
        require(_msgSender() == setupManager, "NFTFactory: Only factory maker can perform");
        require(_isApprovedOrOwner(from, tokenID), "NFTFactory: Not owner");
        _transfer(from, to, tokenID);
    }

    // Convenience method for easy burns via NFTFactoryManager
    // NFTFactoryManager must pass _msgSender() in `from` param
    function managedBurn(
        address from,
        uint256 tokenID
    ) external {
        require(_msgSender() == setupManager, "NFTFactory: Only factory maker can perform");
        require(_isApprovedOrOwner(from, tokenID), "NFTFactory: Not owner");
        _burn(tokenID);
    }

    /**
     * @dev creator mints directly to the contract
     *
     * @param tos address[] array of recipients to mint to
     * @param tokenRoyalties uint256[] array of royalty percentages, 0-10000. 2.5% is 250.
     * @param tokenURIs string[] array of metadata URIs for each token
     */
    function mintBatch(
        address[] memory tos,
        uint256[] memory tokenRoyalties,
        string[] memory tokenURIs
    ) external {
        require(Group(creatorGroup).isMember(_msgSender()), "NFTFactory: Invalid creator address");
        require(
            tos.length == tokenRoyalties.length &&
            tos.length == tokenURIs.length,
            ERROR_INVALID_INPUTS
        );

        uint256 tokenIDBase = directMintRangeStart + directMintOffset;

        for (uint256 i = 0; i < tos.length; ++i) {
            uint256 tokenID = tokenIDBase + i;
            _mint(tos[i], tokenID);
            _setTokenRoyalty(tokenID, tokenRoyalties[i]);
            _setTokenURI(tokenID, tokenURIs[i]);
        }
        directMintOffset += tos.length;
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

    function existsBatch(
        uint256[] memory tokenIDs
    ) external view returns (bool[] memory) {
        bool[] memory exists = new bool[](tokenIDs.length);
        for (uint256 i = 0; i < tokenIDs.length; ++i) {
            exists[i] = _exists(tokenIDs[i]);
        }
        return exists;
    }

    function isApprovedOrOwner(
        address spender,
        uint256 tokenID
    ) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenID);
    }


    /* -- BEGIN ERC2981 supporting methods */
    function royaltyInfo(
        uint256 tokenID,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyReceiver;
        royaltyAmount = salePrice * royaltyAmounts[tokenID] / MAX_ROYALTY;
        return (receiver, royaltyAmount);
    }

    function changeRoyaltyReceiver(address newReceiver) external {
        require(Group(creatorGroup).isMember(_msgSender()), "NFTFactory: Not authorized to change royalty receiver");
        royaltyReceiver = newReceiver;
    }

    function _setTokenRoyalty(uint256 tokenID, uint256 tokenRoyalty) internal {
        require(tokenRoyalty <= MAX_ROYALTY, "NFTFactory: Royalty exceeds 100% (represented as 10000).");
        royaltyAmounts[tokenID] = tokenRoyalty;
    }
    /* -- END ERC2981 supporting methods */


    /* -- BEGIN IRelayRecipient overrides -- */
    function _msgSender() internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    string public override versionRecipient = "1";
    /* -- END IRelayRecipient overrides -- */
}
