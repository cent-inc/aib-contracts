// SPDX-License-Identifier: MIT
import './BaseRelayRecipient.sol';
import './CloneFactory.sol';
import './NFTFactory.sol';

pragma solidity 0.6.12;

contract NFTFactoryDeployer is BaseRelayRecipient, CloneFactory {
    address base;
    constructor() public {
        base = address(new NFTFactory());
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
    }

    function deploy(address creatorGroup, address managerGroup) external returns (address) {
        address clone = createClone(base);
        NFTFactory(clone).init(creatorGroup, managerGroup, _msgSender());
        return clone;
    }

    string public override versionRecipient = "1";
}
