// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721, ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC721Permit} from "./ERC721Permit.sol";

abstract contract ZombieFactory is ERC721URIStorage, ERC721Permit {
    error ZombieFactory__AlreadyHaveZombie();
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event NewZombie(uint256 zombieId, string name, uint256 dna);
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 constant DNA_DIGITS = 16;
    uint256 constant DNA_MODULUS = 10 ** DNA_DIGITS;
    uint256 constant COOL_DOWN_TIME = 1 days;

    struct Zombie {
        string name;
        uint256 dna;
        uint32 level;
        uint32 readyTime;
        uint16 winCount;
        uint16 lossCount;
    }

    Zombie[] public s_zombies;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // function transferFrom(address from, address to, uint256 tokenId)
    //     public
    //     virtual
    //     override(IERC721, ERC721, ERC721Permit)
    // {
    //     ERC721Permit.transferFrom(from, to, tokenId);
    // }

    function _createZombie(string memory _name, uint256 _dna) internal virtual {
        s_zombies.push(Zombie(_name, _dna, 1, uint32(block.timestamp + COOL_DOWN_TIME), 0, 0));
        uint256 tokenId = s_zombies.length - 1;
        _safeMint(msg.sender, tokenId);
        // _setTokenURI(tokenId, uri);
        emit NewZombie(tokenId, _name, _dna);
    }

    function _generateRandomDna(string memory _str) private pure returns (uint256) {
        uint256 rand = uint256(keccak256(abi.encodePacked(_str)));
        return rand % DNA_MODULUS;
    }

    function createRandomZombie(string memory _name) public virtual {
        if (balanceOf(msg.sender) != 0) {
            revert ZombieFactory__AlreadyHaveZombie();
        }
        uint256 randDna = _generateRandomDna(_name);
        randDna = randDna - randDna % 100;
        _createZombie(_name, randDna);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721URIStorage, ERC721Permit)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || ERC721URIStorage.supportsInterface(interfaceId);
    }

    function getAllZombies() public view virtual returns (Zombie[] memory) {
        return s_zombies;
    }
}
