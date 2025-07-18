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
    address linkToken;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public FOUNDRY_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() external {
        if (block.chainid == 31337) {
            vm.deal(FOUNDRY_DEFAULT_SENDER, 100 ether);
            vm.roll(1);
        }

        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory defaultConfig = helper.getConfig();
        account = defaultConfig.account;
        linkToken = defaultConfig.vrfConfig.link;
        deal(linkToken, account, 10 ether);
        vm.deal(account, 100 ether);

        DeployRandomNumberGenerator deployer = new DeployRandomNumberGenerator();
        (randomNumberGenerator, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.vrfConfig.subscriptionId;
        gasLane = config.vrfConfig.gasLane;
        callbackGasLimit = config.vrfConfig.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfConfig.vrfCoordinatorV2_5;
    }

    /// forge test --mt testDeployRandomNumberGeneratorOnMainNet --fork-url $MAINNET_ALCHEMY_RPC_URL -vvv
    function testDeployRandomNumberGeneratorOnMainNet() public {
        console2.log("Deploying RandomNumberGenerator on Mainnet");
        if (block.chainid != 1) {
            return;
        }
        vm.startPrank(account);
        randomNumberGenerator.grantSubscriberRole(account);
        randomNumberGenerator.setSenderNumWords(uint32(1));
        vm.stopPrank();

        vm.recordLogs();
        vm.prank(account);
        randomNumberGenerator.requestRandomWords(); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        // cast storage 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a  --rpc-url $MAINNET_ALCHEMY_RPC_URL
        // cast storage 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a 0 --rpc-url $MAINNET_ALCHEMY_RPC_URL
        // 0x000000000000000000000000cc4b5b07316be81ed6edb44ca61e4cab28a1950d
        address vrfCoordinatorOwner = 0xcc4b5b07316Be81ED6edB44Ca61E4CaB28A1950D;
        // vm.deal(vrfCoordinatorOwner, 100 ether);
        // deal(linkToken, vrfCoordinatorOwner, 100 ether);
        // vm.prank(vrfCoordinatorOwner);
        // VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
        //     uint256(requestId), address(randomNumberGenerator)
        // );
        // fulfillRandomWords 需要真实执行交易，执行者必须是 Chainlink 的签名者。 正式环境的调用参数也不一样,需要真实链上的参数
        // Function: fulfillRandomWords(tuple proof,tuple rc,bool onlyPremium)
        // Assert
        (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers) =
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).getSubscription(subscriptionId);

        console2.log("RandomNumberGenerator deployed at: ", address(randomNumberGenerator));
        console2.log("subscriptionId link balance: ", balance);
        console2.log("subscriptionId reqCount: ", reqCount);
        console2.log("subscriptionId owner: ", owner);
        for (uint256 i = 0; i < consumers.length; i++) {
            console2.log("subscriptionId consumers: ", consumers[i]);
        }
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////
    /// forge test --mt testFulfillRandomWordsCanOnlyBeCalledAfterRequest
    function testFulfillRandomWordsCanOnlyBeCalledAfterRequest() public {
        if (block.chainid != 31337) {
            return;
        }
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
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).getSubscription(subscriptionId);

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
