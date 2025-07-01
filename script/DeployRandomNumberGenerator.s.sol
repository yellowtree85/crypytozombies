// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {RandomNumberGenerator} from "../src/RandomNumberGenerator.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";
// forge script script/DeployRandomNumberGenerator.s.sol:DeployRandomNumberGenerator --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvvv
// make deploy ARGS="--network sepolia"

contract DeployRandomNumberGenerator is Script {
    function run() external returns (RandomNumberGenerator, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        AddConsumer addConsumer = new AddConsumer();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            uint256 subscriptionId;
            (subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5, config.account);
            config.subscriptionId = subscriptionId;

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account
            );
            helperConfig.setConfig(block.chainid, config);
        }
        vm.startBroadcast(config.account);
        RandomNumberGenerator randomNumberGenerator = new RandomNumberGenerator(
            config.subscriptionId, config.gasLane, config.callbackGasLimit, config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();
        console2.log("RandomNumberGenerator deployed at: ", address(randomNumberGenerator));
        // We already have a broadcast in here
        addConsumer.addConsumer(
            address(randomNumberGenerator), config.vrfCoordinatorV2_5, config.subscriptionId, config.account
        );

        return (randomNumberGenerator, helperConfig);
    }
}
