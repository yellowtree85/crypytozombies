// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {ZombieAttack} from "../src/ZombieAttack.sol";

/// forge script script/InteractionsZombies.s.sol:CreateRandomZombie
contract CreateRandomZombie is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("ZombieAttack", block.chainid);
        createRandomZombieUsingConfig(mostRecentlyDeployed, "Zombie1");
    }

    function createRandomZombieUsingConfig(address _zombieAttack, string memory _zombieName) public {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getConfig().account;
        createRandomZombie(_zombieAttack, _zombieName, account);
    }

    function createRandomZombie(address _zombieAttack, string memory _zombieName, address _account) public {
        vm.startBroadcast(_account);
        ZombieAttack(_zombieAttack).createRandomZombie(_zombieName);
        vm.stopBroadcast();
    }
}
