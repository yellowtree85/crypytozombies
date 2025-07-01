// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {RandomNumberGenerator} from "src/RandomNumberGenerator.sol";
import {DeployRandomNumberGenerator} from "script/DeployRandomNumberGenerator.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";

contract SubscriptioManagerTest is StdCheats, Test {
    /* Errors */

    HelperConfig public helperConfig;
    RandomNumberGenerator public randomNumberGenerator;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    address account;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        vm.roll(1);
        DeployRandomNumberGenerator deployer = new DeployRandomNumberGenerator();
        (randomNumberGenerator, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        account = config.account;
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////
    /// forge test --mt testFulfillRandomWordsCanOnlyBeCalledAfterRequest
    function testFulfillRandomWordsCanOnlyBeCalledAfterRequest() public {
        // Arrange
        // Act / Assert
        vm.expectRevert();
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(0, address(randomNumberGenerator));

        vm.expectRevert();

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(1, address(randomNumberGenerator));
    }

    /// forge test --mt testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney --rpc-url http://localhost:8545 --gas 100000000
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public {
        if (block.chainid != 31337) {
            return;
        }
        // fulfillRandomWords
        // s_vrfCallBackInterface.vrfCallback(s_requestId, randomWords);
        // Act
        // address player = vm.envAddress("ACCOUNT_SEPOLIA");
        vm.startPrank(account);
        randomNumberGenerator.grantSubscriberRole(account);
        randomNumberGenerator.setSenderNumWords(uint32(1));
        vm.stopPrank();

        vm.recordLogs();
        vm.prank(account);
        randomNumberGenerator.requestRandomWords(); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        (uint96 startbalance,,,,) = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).getSubscription(subscriptionId);
        console2.log("Current LINK balance:", startbalance);

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            uint256(requestId), address(randomNumberGenerator)
        );

        // Assert
        (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers) =
            randomNumberGenerator.getSubscription(subscriptionId);

        console2.log("SubscriptionManager deployed at: ", address(randomNumberGenerator));
        console2.log("SubscriptionManager link balance: ", balance);
        console2.log("SubscriptionManager reqCount: ", reqCount);
        console2.log("SubscriptionManager owner: ", owner);
        for (uint256 i = 0; i < consumers.length; i++) {
            console2.log("SubscriptionManager consumers: ", consumers[i]);
        }

        console2.log(" LINK balance after fulfillRandomWords:", balance);
        console2.log(" Link used in fulfillRandomWords:", startbalance - balance);
        console2.log("randomNumberGenerator.getRandowNumbers ", randomNumberGenerator.getRandowNumbers(account)[0]);
    }
}
