import "./NFTFactory.sol";
import "./Group.sol";

pragma solidity >=0.4.22 <0.9.0;

contract Mothership {
    function ignitionSequence (address creator, address managerGroup) public {

        Group newGroup = new Group(creator);
        
        NFTFactory newFactory = new NFTFactory(address(newGroup), managerGroup);
     } 

    constructor() public {
        
    }
}
