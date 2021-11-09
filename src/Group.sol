// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/utils/EnumerableSet.sol';
import 'openzeppelin-solidity/contracts/utils/Address.sol';
import './BaseRelayRecipient.sol';

pragma solidity 0.6.12;
/**
 * A Group has 1 admin and 1+ members
 */
contract Group is BaseRelayRecipient{
    using EnumerableSet for EnumerableSet.AddressSet;

    address private admin;
    address private nominatedAdmin;
    address[] private memberLog;
    address private constant NULL_ADDRESS = 0x0000000000000000000000000000000000000000;
    // mapping(address => bool) private members;
    EnumerableSet.AddressSet private members;

    modifier onlyAdmin {
        require(_msgSender() == getAdmin(), "Only Admin");
        _;
    }

    constructor() public {
        admin = _msgSender();
    }

    /**
     * @dev admin function to add a member to the group
     *
     * @param newMember address the address add
     */
    function addMember(address newMember) public onlyAdmin {
        members.add(newMember);
    }

    function removeMember(address existingMember) public onlyAdmin {
        members.remove(existingMember);
    }

    /**
     * @dev admin function to nominate a new admin
     *
     * @param newAdmin address the new admin to assign, which manages members
     */
    function nominateAdmin(address newAdmin) public onlyAdmin {
        nominatedAdmin = newAdmin;
    }

    /**
     * @dev function accept admin nomination a new admin
     */
    function acceptAdmin() public {
        require(_msgSender() != NULL_ADDRESS, 'Group: No nominee');
        require(_msgSender() == nominatedAdmin, 'Group: Incorrect nominee');
        admin = nominatedAdmin;
        nominatedAdmin = NULL_ADDRESS;
    }

    function getMemberCount() public view returns (uint256) {
        return members.length();
    }

    function getMemberByIndex(uint256 index) public view returns (address) {
        return members.at(index);
    }

    function getAdmin() public view returns (address) {
        return admin;
    }

    function isMember(address addr) public view returns (bool) {
        return members.contains(addr) || getAdmin() == addr;
    }

    string public override versionRecipient = "1";
}
