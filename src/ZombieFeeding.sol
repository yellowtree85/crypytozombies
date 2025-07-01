// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZombieFactory} from "./ZombieFactory.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {IVRFv2PlusSubscriptionManager} from "./interfaces/IVRFv2PlusSubscriptionManager.sol";

interface IKittyInterface {
    function getKitty(uint256 _id)
        external
        view
        returns (
            bool isGestating,
            bool isReady,
            uint256 cooldownIndex,
            uint256 nextActionAt,
            uint256 siringWithId,
            uint256 birthTime,
            uint256 matronId,
            uint256 sireId,
            uint256 generation,
            uint256 genes
        );
}

abstract contract ZombieFeeding is ZombieFactory, Ownable {
    IKittyInterface kittyContract;
    // IVRFv2PlusSubscriptionManager public subscriptionManager;

    modifier onlyOwnerOf(uint256 _zombieId) {
        require(msg.sender == ownerOf(_zombieId));
        _;
    }

    // modifier onlyOwnerOrManagerOf(uint256 _zombieId) {
    //     require(msg.sender == ownerOf(_zombieId) || msg.sender == address(subscriptionManager));
    //     _;
    // }

    // constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) Ownable(msg.sender) {}

    function setKittyContractAddress(address _address) external virtual onlyOwner {
        kittyContract = IKittyInterface(_address);
    }

    function _triggerCooldown(Zombie storage _zombie) internal virtual {
        _zombie.readyTime = uint32(block.timestamp + COOL_DOWN_TIME);
    }

    function _isReady(Zombie storage _zombie) internal view virtual returns (bool) {
        return (_zombie.readyTime <= block.timestamp);
    }

    function feedAndMultiply(uint256 _zombieId, uint256 _targetDna, string memory _species)
        internal
        virtual
        onlyOwnerOf(_zombieId)
    {
        Zombie storage myZombie = s_zombies[_zombieId];
        require(_isReady(myZombie));
        _targetDna = _targetDna % DNA_MODULUS;
        uint256 newDna = (myZombie.dna + _targetDna) / 2;
        if (keccak256(abi.encodePacked(_species)) == keccak256(abi.encodePacked("kitty"))) {
            newDna = newDna - newDna % 100 + 99;
        }
        _createZombie("NoName", newDna);
        _triggerCooldown(myZombie);
    }

    function feedOnKitty(uint256 _zombieId, uint256 _kittyId) public virtual {
        uint256 kittyDna;
        (,,,,,,,,, kittyDna) = kittyContract.getKitty(_kittyId);
        feedAndMultiply(_zombieId, kittyDna, "kitty");
    }

    function getKittyContractAddress() external view virtual returns (address) {
        return address(kittyContract);
    }
}
