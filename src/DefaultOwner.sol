// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;
interface DefaultOwner {
    function getDefaultOwner() external view returns (address owner);
}