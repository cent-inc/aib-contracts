// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Burnable.sol';
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import 'openzeppelin-solidity/contracts/utils/Strings.sol';
import './IERC2981.sol';
import './DefaultOwner.sol';
import './BaseRelayRecipient.sol';

pragma solidity 0.6.12;

contract NFTFactory is ERC721Burnable, BaseRelayRecipient, IERC2981 {
    string public constant override versionRecipient = "1"; // For IRelayRecipient

    string private constant COLLECTION_PREFIX = "Collection: ";
    string private constant TOKEN_PREFIX = "\n\nToken: ";
    uint256 private constant MAX_ROYALTY = 10000; // 100%

    address private manager;
    address private contractOwner;
    address public creator;
    uint256 public royaltyRate;
    address public royaltyReceiver;
    string private tokenName;
    string private tokenSymbol;
    string public contractURI;
    enum MINT_STATE { NONE, ACTIVE, ENDED }

    mapping(uint256 => bytes32) private tokenIDToTypeID;
    mapping(bytes32 => TokenType) tokenTypes;

    struct TokenType {
        MINT_STATE state;
        string uri;
    }

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event RoyaltiesTransferred(
        address indexed previousRoyaltyReceiver,
        address indexed newRoyaltyReceiver
    );

    modifier onlyManager {
      require(_msgSender() == manager, "NFTFactory: Only Manager");
      _;
    }

    constructor() public ERC721("","") {
        contractOwner = _msgSender();
    }

    // Because we use a `CloneFactory` we move any constructor logic into an `init` method
    function init(
        address _creator,
        address _royaltyReceiver,
        uint256 _royaltyRate,
        string memory _tokenName,
        string memory _tokenSymbol,
        string memory _contractURI
    ) public {
        require(manager == address(0), "NFTFactory: Already Initialized");
        manager = _msgSender();
        creator = _creator;
        royaltyRate = _royaltyRate;
        royaltyReceiver = _royaltyReceiver;
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
        contractURI = _contractURI;
    }

    // Managed mint of a tokenURI
    function managedMint(
        address to,
        uint256 tokenID,
        string memory tokenURI,
        bytes memory creatorSignature
    ) public {
        bytes32 typeID = _getTypeID(tokenURI);

        MINT_STATE currentState = tokenTypes[typeID].state;

        if (currentState == MINT_STATE.NONE) {
            // Create a new token type
            string memory collectionURI = contractURI;
            uint256 creatorMessageLength = bytes(COLLECTION_PREFIX).length
            + bytes(collectionURI).length
            + bytes(TOKEN_PREFIX).length
            + bytes(tokenURI).length;

            bytes32 creatorMessageHash = keccak256(abi.encodePacked(
                "\x19Ethereum Signed Message:\n",
                Strings.toString(creatorMessageLength),
                COLLECTION_PREFIX,
                collectionURI,
                TOKEN_PREFIX,
                tokenURI
            ));
            require(ECDSA.recover(creatorMessageHash, creatorSignature) == creator, "NFTFactory: Invalid signature");
            _initTokenType(typeID, tokenURI);
        }
        else if (currentState == MINT_STATE.ENDED) {
            revert("NFTFactory: Minting ended");
        }

        _setTokenType(tokenID, typeID);
        _mint(to, tokenID);
    }

    // End managed minting of token if the supply cap is not hit
    function managedCap(
        string memory tokenURI
    ) external onlyManager {
        tokenTypes[_getTypeID(tokenURI)].state = MINT_STATE.ENDED;
    }

    // Convenience method for easy transfers via NFTFactoryManager
    // Factory Manager must pass _msgSender() in `from` param
    function managedTransfer(
        address from,
        address to,
        uint256 tokenID
    ) external onlyManager {
        require(_isApprovedOrOwner(from, tokenID), "NFTFactory: Not owner");
        _transfer(from, to, tokenID);
    }

    // Convenience method for easy burns via NFTFactoryManager
    // NFTFactoryManager must pass _msgSender() in `from` param
    function managedBurn(
        address from,
        uint256 tokenID
    ) external onlyManager {
        require(_isApprovedOrOwner(from, tokenID), "NFTFactory: Not owner");
        _burn(tokenID);
    }

    function _getTypeID(
        string memory uri
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(uri));
    }

    function _setTokenType(
        uint256 tokenID,
        bytes32 typeID
    ) internal {
        tokenIDToTypeID[tokenID] = typeID;
    }

    function _getTokenType(
        uint256 tokenID
    ) internal view returns (bytes32) {
        return tokenIDToTypeID[tokenID];
    }

    function _initTokenType(
        bytes32 typeID,
        string memory uri
    ) internal {
        tokenTypes[typeID].state = MINT_STATE.ACTIVE;
        tokenTypes[typeID].uri = uri;
    }

    function exists(
        uint256 tokenID
    ) external view returns (bool) {
        return _exists(tokenID);
    }

    function isApprovedOrOwner(
        address spender,
        uint256 tokenID
    ) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenID);
    }

    function tokenURI(
        uint256 tokenID
    ) public virtual view override returns (string memory) {
        require(_exists(tokenID), "NFTFactory: Token not found");
        return tokenTypes[_getTokenType(tokenID)].uri;
    }

    function name(
    ) public view override returns (string memory) {
        return tokenName;
    }

    function symbol(
    ) public view override returns (string memory) {
        return tokenSymbol;
    }

    /* -- ERC2981 support */
    function royaltyInfo(
        uint256 tokenID,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenID), "NFTFactory: Token not found");
        receiver = royaltyReceiver;
        royaltyAmount = salePrice * royaltyRate / MAX_ROYALTY;
        return (receiver, royaltyAmount);
    }

    /* -- IRelayRecipient override -- */
    function _msgSender(
    ) internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    /* -- `Ownable` support -- */
    function owner(
    ) public view returns (address) {
        address currentOwner = contractOwner;
        if (currentOwner == address(0)) {
            return DefaultOwner(manager).getDefaultOwner();
        }
        return currentOwner;
    }

    function transferOwnership(
        address newOwner
    ) public {
        address currentOwner = owner();
        require(_msgSender() == currentOwner, "NFTFactory: not owner");
        require(newOwner != address(0), "NFTFactory: new owner is the zero address");
        emit OwnershipTransferred(currentOwner, newOwner);
        contractOwner = newOwner;
    }
    function transferRoyalties(
        address newRoyaltyReceiver
    ) public {
        require(_msgSender() == owner(), "NFTFactory: not owner");
        require(newRoyaltyReceiver != address(0), "NFTFactory: new owner is the zero address");
        emit RoyaltiesTransferred(royaltyReceiver, newRoyaltyReceiver);
        royaltyReceiver = newRoyaltyReceiver;
    }

    /* -- ERC-165 Support -- */
    function supportsInterface(
        bytes4 interfaceID
    ) public view override(ERC165, IERC165) returns (bool) {
        return interfaceID == 0x80ac58cd //_INTERFACE_ID_ERC721
        || interfaceID == 0x5b5e139f //_INTERFACE_ID_ERC721_METADATA
        || interfaceID == 0x780e9d63 //_INTERFACE_ID_ERC721_ENUMERABLE
        || interfaceID == 0x2a55205a; //_INTERFACE_ID_ERC2981
    }

}
