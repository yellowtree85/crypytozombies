// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ZombieAttack} from "../src/ZombieAttack.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IVRFv2PlusSubscriptionManager} from "src/interfaces/IVRFv2PlusSubscriptionManager.sol";

/// forge script script/DeployZombieAttack.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvvv

contract DeployZombieAttack is Script {
    ZombieAttack public zombieAttack;
    IVRFv2PlusSubscriptionManager public subscriptionManager;

    function run() public returns (ZombieAttack) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // cann't use this while using uint forge test
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("RandomNumberGenerator", block.chainid);
        console2.log("Most recently deployed RandomNumberGenerator: ", mostRecentlyDeployed);
        return deploy(mostRecentlyDeployed, config.account);
    }

    function deploy(address _mostRecentlyDeployed, address account) public returns (ZombieAttack) {
        subscriptionManager = IVRFv2PlusSubscriptionManager(_mostRecentlyDeployed);

        vm.startBroadcast(account);
        zombieAttack = new ZombieAttack("ZombieAttack", "ZATK", _mostRecentlyDeployed);
        // 给订阅者赋权限
        subscriptionManager.grantSubscriberRole(address(zombieAttack));
        // 设置随机数的数量
        zombieAttack.setSenderNumWords(uint32(1));
        vm.stopBroadcast();
        return zombieAttack;
    }
}
