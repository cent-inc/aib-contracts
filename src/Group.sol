// SPDX-License-Identifier: MIT
import 'openzeppelin-solidity/contracts/utils/EnumerableSet.sol';
import 'openzeppelin-solidity/contracts/utils/Address.sol';
import 'openzeppelin-solidity/contracts/GSN/Context.sol';

pragma solidity 0.6.12;
/**
 * A Group has 1 admin and 1+ members
 */
contract Group is Context {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private admin;
    address private nominatedAdmin;

    EnumerableSet.AddressSet private members;

    modifier onlyAdmin {
        require(_msgSender() == getAdmin(), "Only Admin");
        _;
    }

    constructor(
    ) public {
        admin = _msgSender();
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
        require(nominatedAdmin != address(0), 'Group: No nominee');
        require(nominatedAdmin == _msgSender(), 'Group: Incorrect nominee');
        admin = nominatedAdmin;
        nominatedAdmin = address(0);
    }

    function getMemberCount() public view returns (uint256) {
        return members.length();
    }

    function getMemberByIndex(uint256 index) external view returns (address) {
        return members.at(index);
    }

    function isMember(address addr) public view returns (bool) {
        return members.contains(addr) || getAdmin() == addr;
    }

    function getAdmin() public view returns (address) {
        return admin;
    }

    function getNominee() public view returns (address) {
        return nominatedAdmin;
    }
}
