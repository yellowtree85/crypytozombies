// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.001 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant LINK_BALANCE = 100 ether;

    address public FOUNDRY_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    bytes32 public constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");

    string public constant EIP712DOMAIN_NAME = "ZombieAttack";
    string public constant ERC721_SYMBOL = "ZATK";
    string public constant EIP712DOMAIN_VERSION = "1";
}

contract HelperConfig is CodeConstants, Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HelperConfig__InvalidChainId();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2_5;
        address link;
        address account;
        uint256 deadline;
        bytes32 eip712DomainTypeHash;
        bytes32 permitTypeHash;
        string eip712DomainName;
        string erc721Symbol;
        string eip712DomainVersion;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    // Local network state variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        // Note: We skip doing the local config
    }

    function getConfig() public returns (NetworkConfig memory) {
        console2.log("on chainId: ", block.chainid);
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            gasLane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x99519313208858E2c35da7Dd5449449eA88a4493,
            deadline: 1789716500,
            eip712DomainTypeHash: EIP712DOMAIN_TYPEHASH,
            permitTypeHash: PERMIT_TYPEHASH,
            eip712DomainName: EIP712DOMAIN_NAME,
            erc721Symbol: ERC721_SYMBOL,
            eip712DomainVersion: EIP712DOMAIN_VERSION
        });
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            // subscriptionId: 9985493892126651747780725050076838928105990851924659843866228520163437646077, // If left as 0, our scripts will create one!
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x99519313208858E2c35da7Dd5449449eA88a4493,
            deadline: 1789716500,
            eip712DomainTypeHash: EIP712DOMAIN_TYPEHASH,
            permitTypeHash: PERMIT_TYPEHASH,
            eip712DomainName: EIP712DOMAIN_NAME,
            erc721Symbol: ERC721_SYMBOL,
            eip712DomainVersion: EIP712DOMAIN_VERSION
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return localNetworkConfig;
        }

        console2.log(unicode"⚠️ You have deployed a mock conract!");
        console2.log("Make sure this was intentional");
        vm.startBroadcast(FOUNDRY_DEFAULT_SENDER);
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        console2.log("create VRFCoordinatorV2_5Mock: ", address(vrfCoordinatorV2_5Mock));
        LinkToken link = new LinkToken();
        console2.log("Creating LinkToken: ", address(link));
        console2.log("FOUNDRY_DEFAULT_SENDER: %s", FOUNDRY_DEFAULT_SENDER);
        console2.log("FOUNDRY_DEFAULT_SENDER link balance: ", link.balanceOf(FOUNDRY_DEFAULT_SENDER));
        console2.log("FOUNDRY_DEFAULT_SENDER ETH balance: ", FOUNDRY_DEFAULT_SENDER.balance);
        // uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
        // console2.log("Your subscription Id is: ", subscriptionId);
        //本地直接调用fundSubscription 修改balance  线上合约没有这个方法
        // vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, 1 ether);
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: 0,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesn't really matter
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: address(vrfCoordinatorV2_5Mock),
            link: address(link),
            account: FOUNDRY_DEFAULT_SENDER,
            deadline: 1789716500,
            eip712DomainTypeHash: EIP712DOMAIN_TYPEHASH,
            permitTypeHash: PERMIT_TYPEHASH,
            eip712DomainName: EIP712DOMAIN_NAME,
            erc721Symbol: ERC721_SYMBOL,
            eip712DomainVersion: EIP712DOMAIN_VERSION
        });
        // vm.deal(localNetworkConfig.account, 100 ether);

        networkConfigs[LOCAL_CHAIN_ID] = localNetworkConfig;
        return localNetworkConfig;
    }
}
