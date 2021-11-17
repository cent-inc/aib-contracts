// SPDX-License-Identifier: MIT
import './BaseRelayRecipient.sol';
import './NFTFactory.sol';

pragma solidity 0.6.12;

contract NFTFactoryDeployer is BaseRelayRecipient {
    function deploy(address creatorGroup, address managerGroup) external returns (address) {
        NFTFactory factory = new NFTFactory(creatorGroup, managerGroup);
        return address(factory);
    }

    string public override versionRecipient = "1";
}
