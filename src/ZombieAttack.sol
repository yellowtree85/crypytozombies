// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZombieHelper} from "./ZombieHelper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IVRFv2PlusSubscriptionManager} from "./interfaces/IVRFv2PlusSubscriptionManager.sol";
import {IVRFCallBackInterface} from "src/interfaces/IVRFCallBackInterface.sol";
import {console2} from "lib/forge-std/src/console2.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ZombieAttack is ZombieHelper, IVRFCallBackInterface, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZombieAttack__NeedMoreGasForMint();
    error ZombieAttack__YouAlreadAttackedAZombie(uint256 zombieId);
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AttackZombie(address indexed owner, uint256 zombieId, uint256 targetId, uint256 requestId);
    event AttackWinerShouldMintZombie(address indexed owner, uint256 zombieId, uint256 targetDna);
    event AttackZombieResult(address indexed owner, uint256 zombieId, uint256 targetId, bool winOrloss);

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 attackVictoryProbability = 70;
    IVRFv2PlusSubscriptionManager public subscriptionManager;
    uint256 public s_mintZombieFee = 0.001 ether;

    struct AttackInfo {
        bool success;
        bool winOrloss;
        uint256 attackId;
        uint256 targetId;
        uint256 randomNum;
    }

    mapping(address => uint256) public s_attackToRequestId;
    mapping(uint256 => AttackInfo) public s_requestAttackInfos;

    modifier attackCheck() {
        uint256 requestId = s_attackToRequestId[msg.sender];
        if (requestId != 0 && requestId != type(uint96).max) {
            revert ZombieAttack__YouAlreadAttackedAZombie(s_requestAttackInfos[requestId].targetId);
        }
        _;
    }

    constructor(string memory _name, string memory _symbol, address _subscriptionManager)
        ERC721(_name, _symbol)
        EIP712(_name, "1")
        Ownable(msg.sender)
    {
        subscriptionManager = IVRFv2PlusSubscriptionManager(_subscriptionManager);
    }

    function setMintZombieFee(uint256 _fee) external onlyOwner {
        s_mintZombieFee = _fee;
    }

    function setRandomNumberGenerator(address _subscriptionManager) external onlyOwner {
        subscriptionManager = IVRFv2PlusSubscriptionManager(_subscriptionManager);
    }

    function setSenderNumWords(uint32 _numWords) external onlyOwner {
        subscriptionManager.setSenderNumWords(_numWords);
    }

    function attack(uint256 _zombieId, uint256 _targetId) external nonReentrant attackCheck onlyOwnerOf(_zombieId) {
        // get random data from vrf
        s_attackToRequestId[msg.sender] = type(uint96).max;
        uint256 requestId = subscriptionManager.requestRandomWords();
        s_attackToRequestId[msg.sender] = requestId;
        s_requestAttackInfos[requestId] = AttackInfo(false, false, _zombieId, _targetId, 0);
        emit AttackZombie(msg.sender, _zombieId, _targetId, requestId);
    }

    function getAttackInfo(address _user) external view returns (AttackInfo memory) {
        uint256 requestId = s_attackToRequestId[_user];
        return s_requestAttackInfos[requestId];
    }

    function vrfCallback(uint256 requestId, uint256[] calldata randomWords) external override {
        require(msg.sender == address(subscriptionManager));
        AttackInfo storage attackInfo = s_requestAttackInfos[requestId];
        if (attackInfo.success) {
            return;
        }

        attackInfo.success = true; // only call once
        uint256 rand = randomWords[0] % 100 + 1;
        attackInfo.randomNum = rand;
        uint256 _zombieId = attackInfo.attackId;
        uint256 _targetId = attackInfo.targetId;
        Zombie storage myZombie = s_zombies[_zombieId];
        Zombie storage enemyZombie = s_zombies[_targetId];
        if (rand <= attackVictoryProbability) {
            attackInfo.winOrloss = true;
            myZombie.winCount++;
            myZombie.level++;
            enemyZombie.lossCount++;
            emit AttackWinerShouldMintZombie(ownerOf(_zombieId), _zombieId, enemyZombie.dna);
        } else {
            delete s_attackToRequestId[ownerOf(_zombieId)];
            delete s_requestAttackInfos[requestId];

            myZombie.lossCount++;
            enemyZombie.winCount++;
            _triggerCooldown(myZombie);
        }
        emit AttackZombieResult(ownerOf(_zombieId), _zombieId, _targetId, attackInfo.winOrloss);
    }

    function winerMintZombie(uint256 _zombieId, uint256 _targetDna) external payable virtual onlyOwnerOf(_zombieId) {
        if (msg.value < s_mintZombieFee) {
            revert ZombieAttack__NeedMoreGasForMint();
        }
        uint256 requestId = s_attackToRequestId[msg.sender];
        delete s_attackToRequestId[msg.sender];
        delete s_requestAttackInfos[requestId];

        feedAndMultiply(_zombieId, _targetDna, "zombie");
    }

    function name() public view override returns (string memory) {
        return super.name();
    }

    function symbol() public view override returns (string memory) {
        return super.symbol();
    }
}
