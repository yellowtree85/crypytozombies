// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {CodeConstants} from "./HelperConfig.s.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfConfig.vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        return createSubscription(vrfCoordinatorV2_5, account);
    }

    function createSubscription(address vrfCoordinatorV2_5, address account) public returns (uint256, address) {
        console2.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).createSubscription();
        vm.stopBroadcast();
        console2.log("createSubscription Your subscription Id is: ", subId);
        console2.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinatorV2_5);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console2.log("Adding consumer contract: ", contractToAddToVrf);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        console2.log("Using subscriptionId: ", subId);
        console2.log("On ChainID: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().vrfConfig.subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfConfig.vrfCoordinatorV2_5;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("RandomNumberGenerator", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

contract FundSubscription is CodeConstants, Script {
    uint256 public constant FUND_AMOUNT = 10 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().vrfConfig.subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfConfig.vrfCoordinatorV2_5;
        address link = helperConfig.getConfig().vrfConfig.link;
        address account = helperConfig.getConfig().account;

        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            // (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
            (uint256 updatedSubId, address updatedVRFv2) = createSub.createSubscription(vrfCoordinatorV2_5, account);
            subId = updatedSubId;
            vrfCoordinatorV2_5 = updatedVRFv2;
            console2.log("New SubId Created! ", subId, "VRF Address: ", vrfCoordinatorV2_5);
        }

        fundSubscription(vrfCoordinatorV2_5, subId, link, account);
    }

    function fundSubscription(address vrfCoordinatorV2_5, uint256 subId, address link, address account) public {
        console2.log("Funding subscription: ", subId);
        console2.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console2.log("On ChainID: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            //本地直接调用fundSubscription 修改balance  线上合约没有这个方法
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console2.log("account is ", account);
            console2.log("account balance is ", LinkToken(link).balanceOf(account));
            vm.startBroadcast(account);
            // 非本地网络调用LinkToken的transferAndCall方法
            LinkToken(link).transferAndCall(vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}
