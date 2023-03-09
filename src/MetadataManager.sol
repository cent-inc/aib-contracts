// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

abstract contract MetadataManager {
    function getContractName(address nftContract) external virtual view returns (string memory);
    function getContractSymbol(address nftContract) external virtual view returns (string memory);
    function getContractOwner(address nftContract) external virtual view returns (address);
    function getContractRoyalty(address nftContract) external virtual view returns (uint256);
    function setContractOwner(address nftContract, address newOwner) external virtual;
}