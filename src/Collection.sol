// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Burnable.sol';
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './IERC2981.sol';
import './MetadataManager.sol';
import './BaseRelayRecipient.sol';

pragma solidity 0.6.12;

contract Collection is ERC721Burnable, BaseRelayRecipient, IERC2981 {
    string public constant override versionRecipient = "1"; // For IRelayRecipient

    uint256 private constant MAX_ROYALTY = 10000; // 100%
    uint256 private constant NO_CAP = 0;
    uint256 private constant BITMASK_64 = 0xFFFFFFFFFFFFFFFF;

    MetadataManager private manager;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyManager {
      require(_msgSender() == address(manager), "Collection: Only Manager address can call");
      _;
    }

    constructor() public ERC721("","") {
        manager = MetadataManager(_msgSender());
    }

    // Because we use a `CloneFactory` we move any constructor logic into an `init` method
    function init() public {
        require(address(manager) == address(0), "Collection: Already Initialized");
        manager = MetadataManager(_msgSender());
    }

    uint64 tokenURICount;
    mapping(uint64 => string) tokenURIs;
    mapping(string => uint256) tokenTypes;
    struct TokenType {
        uint64 supply;
        uint64 supplyCap;
        uint64 tokenURIIndex;
    }

    mapping(uint256 => uint64) tokenURIIndices;

    // Managed mint of a tokenURI
    function mintBatch(
        string memory uri,
        uint64 tokenSupplyCap,
        address[] memory recipients,
        uint256[] memory tokenIDs
    ) public onlyManager {
        TokenType memory tt = loadTokenType(tokenTypes[uri]);
        if (tt.tokenURIIndex == 0) {
            tt.supplyCap = tokenSupplyCap;
            tt.tokenURIIndex = ++tokenURICount;
            tokenURIs[tt.tokenURIIndex] = uri;
        }

        uint64 newTokens = uint64(tokenIDs.length);
        uint64 newSupply = tt.supply + newTokens;
        if (tt.supplyCap != NO_CAP) {
            // Check for overflows and that supply is within cap.
            require(newSupply > tt.supply && newSupply <= tt.supplyCap, "Supply capped");
        }
        for (uint64 i = 0; i < newTokens; i++) {
            require(tokenURIIndices[tokenIDs[i]] == 0, "Cannot remint token");
            tokenURIIndices[tokenIDs[i]] = tt.tokenURIIndex;
            _mint(recipients[i], tokenIDs[i]);
        }
        tt.supply = newSupply;
        storeTokenType(uri, tt);
    }

    function loadTokenType(uint256 data) internal pure returns (TokenType memory) {
        return TokenType({
            supply: uint64((data >> 128) & BITMASK_64),
            supplyCap: uint64((data >> 64) & BITMASK_64),
            tokenURIIndex: uint64(data & BITMASK_64)
        });
    }

    function storeTokenType(string memory uri, TokenType memory tt) internal {
        uint256 data =
            (uint256(tt.supply) << 128) +
            (uint256(tt.supplyCap) << 64) +
            uint256(tt.tokenURIIndex)
        ;
        tokenTypes[uri] = data;
    }

    // Convenience method for easy transfers via CollectionManager
    // Factory Manager must pass _msgSender() in `from` param
    function managedTransfer(
        address from,
        address to,
        uint256 tokenID
    ) external onlyManager {
        require(_isApprovedOrOwner(from, tokenID), "Collection: Not owner");
        _transfer(from, to, tokenID);
    }

    // Convenience method for easy burns via CollectionManager
    // CollectionManager must pass _msgSender() in `from` param
    function managedBurn(
        address from,
        uint256 tokenID
    ) external onlyManager {
        require(_isApprovedOrOwner(from, tokenID), "Collection: Not owner");
        _burn(tokenID);
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
        require(_exists(tokenID), "Collection: Token not found");
        return tokenURIs[tokenURIIndices[tokenID]];
    }

    function name(
    ) public view override returns (string memory) {
        return manager.getContractName(address(this));
    }

    function symbol(
    ) public view override returns (string memory) {
        return manager.getContractSymbol(address(this));
    }

    /* -- ERC2981 support */
    function royaltyInfo(
        uint256 tokenID,
        uint256 salePrice
    ) external view override returns (address, uint256) {
        require(_exists(tokenID), "Collection: Token not found");
        address owner = manager.getContractOwner(address(this));
        uint256 royalty = manager.getContractRoyalty(address(this));
        uint256 amount = salePrice * royalty / MAX_ROYALTY;
        return (owner, amount);
    }

    /* -- IRelayRecipient override -- */
    function _msgSender(
    ) internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    /* -- `Ownable` support -- */
    function transferOwnership(
        address newOwner
    ) public {
        address oldOwner = manager.getContractOwner(address(this));
        require(_msgSender() == oldOwner, "Collection: Not Owner");
        manager.setContractOwner(address(this), newOwner);
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function owner() public view returns (address) {
        return manager.getContractOwner(address(this));
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
