// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/de99bccbfd4ecd19d7369d01b070aa72c64423c9
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import './BaseRelayRecipient.sol';

pragma solidity >=0.4.22 <0.9.0;

contract NFBulletin is ERC721, BaseRelayRecipient {

    /*
     * Forwarder singleton we accept calls from
     */
    address private cent;

    constructor() public ERC721("Tests", "TEST") {
        // cent = _msgSender();
        // _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
    }

    /* -- BEGIN IRelayRecipient Implementations -- */
    function _msgSender() internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    string public override versionRecipient = "2.2.0";
    /* -- END IRelayRecipient Implementations -- */
}
