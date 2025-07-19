// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ZombieFeeding} from "./ZombieFeeding.sol";

abstract contract ZombieHelper is ZombieFeeding {
    uint256 levelUpFee = 0.001 ether;

    modifier aboveLevel(uint256 _level, uint256 _zombieId) {
        require(s_zombies[_zombieId].level >= _level);
        _;
    }

    function withdraw() external virtual onlyOwner {
        address _owner = owner();
        (bool success,) = payable(_owner).call{value: address(this).balance}("");
        require(success, "withdraw failed.");
    }

    function setLevelUpFee(uint256 _fee) external virtual onlyOwner {
        levelUpFee = _fee;
    }

    function levelUp(uint256 _zombieId) external payable {
        require(msg.value == levelUpFee);
        s_zombies[_zombieId].level++;
    }

    function changeName(uint256 _zombieId, string memory _newName)
        external
        virtual
        aboveLevel(2, _zombieId)
        onlyOwnerOf(_zombieId)
    {
        s_zombies[_zombieId].name = _newName;
    }

    function changeDna(uint256 _zombieId, uint256 _newDna)
        external
        virtual
        aboveLevel(20, _zombieId)
        onlyOwnerOf(_zombieId)
    {
        s_zombies[_zombieId].dna = _newDna;
    }

    function getZombiesByOwner(address _owner) external view virtual returns (uint256[] memory) {
        uint256[] memory result = new uint256[](balanceOf(_owner));
        uint256 counter = 0;
        for (uint256 i = 0; i < s_zombies.length; i++) {
            if (ownerOf(i) == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }
}
