// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/utils/EnumerableSet.sol';
import 'openzeppelin-solidity/contracts/utils/Address.sol';
import './BaseRelayRecipient.sol';

pragma solidity 0.6.12;
/**
 * A Group has 1 admin and 1+ members
 */
contract Group is BaseRelayRecipient {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private constant NULL_ADDRESS = 0x0000000000000000000000000000000000000000;
    address private admin;
    address private nominatedAdmin;
    address[] private memberLog;
    bool private initialized = false;

    EnumerableSet.AddressSet private members;

    modifier onlyAdmin {
        require(_msgSender() == getAdmin(), "Only Admin");
        _;
    }

    function init(address initialAdmin) public {
        require(initialized == false, "Group: Admin already set");
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
        admin = initialAdmin;
        initialized = true;
    }

    /**
     * @dev admin function to add a member to the group
     *
     * @param newMember address the address add
     */
    function addMember(address newMember) external onlyAdmin {
        members.add(newMember);
    }

    function removeMember(address existingMember) external onlyAdmin {
        members.remove(existingMember);
    }

    /**
     * @dev admin function to nominate a new admin
     *
     * @param newAdmin address the new admin to assign, which manages members
     */
    function nominateAdmin(address newAdmin) external onlyAdmin {
        nominatedAdmin = newAdmin;
    }

    /**
     * @dev function accept admin nomination a new admin
     */
    function acceptAdmin() external {
        require(nominatedAdmin != NULL_ADDRESS, 'Group: No nominee');
        require(nominatedAdmin == _msgSender(), 'Group: Incorrect nominee');
        admin = nominatedAdmin;
        nominatedAdmin = NULL_ADDRESS;
    }

    function getMemberCount() external view returns (uint256) {
        return members.length();
    }

    function getMemberByIndex(uint256 index) external view returns (address) {
        return members.at(index);
    }

    function isMember(address addr) external view returns (bool) {
        return members.contains(addr) || getAdmin() == addr;
    }

    function getAdmin() public view returns (address) {
        return admin;
    }

    function getNominee() public view returns (address) {
        return nominatedAdmin;
    }

    string public override versionRecipient = "1";
}
