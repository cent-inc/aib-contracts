// SPDX-License-Identifier: MIT
import './BaseRelayRecipient.sol';
import './CloneFactory.sol';
import './Group.sol';

pragma solidity 0.6.12;

contract GroupDeployer is BaseRelayRecipient, CloneFactory {
    address base;
    constructor() public {
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
        Group group = new Group();
        group.init(address(this));
        base = address(group);
    }

    function deploy(address admin) external returns (address) {
        address clone = createClone(base);
        Group(clone).init(admin);
        return clone;
    }

    string public override versionRecipient = "1";
}
