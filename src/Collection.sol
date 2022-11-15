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

    // Managed mint of a tokenURI
    function mint(
        address to,
        uint256 tokenID
    ) public onlyManager returns (uint256) {
        // _mint(to, tokenID);
        return totalSupply();
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
        return manager.getTokenURI(address(this), tokenID);
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
