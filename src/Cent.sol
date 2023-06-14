// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import 'openzeppelin-solidity/contracts/access/Ownable.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/math/Math.sol';

contract Cent is ERC20, Ownable {
    mapping(address => bool) private minters;

    uint private NFTTotal = 0;

    uint public constant SINGLE_TOKEN = 1e18;
    uint public constant TOKEN_SUPPLY = 500000000 * SINGLE_TOKEN;
    uint public constant USER_RATES_1 = 100;
    uint public constant USER_RATES_2 = 10;
    uint public constant USER_RATES_3 = 1;
    uint public constant CAP_1 =   1000000;
    uint public constant CAP_2 =  10000000;
    uint public constant CAP_3 = 100000000;

    constructor(address dropRecipient, string memory name, string memory ticker) public ERC20(name, ticker) {
        _mint(address(this), TOKEN_SUPPLY);
        _transfer(address(this), dropRecipient, 80000000 * SINGLE_TOKEN);
    }

    function setMinterEnabled(address minter, bool enabled) public onlyOwner {
        minters[minter] = enabled;
    }

    function onMint(address to, uint256 numNewNFTs) external {
        require(minters[msg.sender], "Caller is not a minter");

        uint[3] memory CAPS = [
            CAP_1,
            CAP_2,
            CAP_3
        ];
        uint[3] memory USER_RATES = [
            USER_RATES_1,
            USER_RATES_2,
            USER_RATES_3
        ];

        uint newNFTTotal = NFTTotal;
        uint uncountedNFTs = numNewNFTs;
        uint newUserTokens = 0;
        uint newTeamTokens = 0;

        for (uint i = 0; i < CAPS.length; i++) {
            if (newNFTTotal < CAPS[i] && uncountedNFTs > 0) {
                uint countedNFTs = Math.min(newNFTTotal + uncountedNFTs, CAPS[i]) - newNFTTotal;
                uncountedNFTs -= countedNFTs;
                newUserTokens += countedNFTs * USER_RATES[i] * SINGLE_TOKEN;
                newTeamTokens += countedNFTs * USER_RATES[i] * SINGLE_TOKEN / 2;
                newNFTTotal += countedNFTs;
            }
        }

        NFTTotal = newNFTTotal + uncountedNFTs;
        if (newUserTokens > 0) {
            _transfer(address(this), to, newUserTokens);
        }
        if (newTeamTokens > 0) {
            _transfer(address(this), owner(), newTeamTokens);
        }
    }

    function getMinterEnabled(address addr) public view returns (bool) {
        return minters[addr];
    }

    function getNFTTotal() public view returns (uint) {
        return NFTTotal;
    }
}