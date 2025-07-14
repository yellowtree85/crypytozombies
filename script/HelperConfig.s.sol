// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.001 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant LINK_BALANCE = 100 ether;

    address public FOUNDRY_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;

    address public constant DAI_MAINNET = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT_MAINNET = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant SWAP_ROUTER2_MAINNET = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address public constant UNISWAP_V3_FACTORY_MAINNET = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    bytes32 public constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");

    string public constant EIP712DOMAIN_NAME = "ZombieAttack";
    string public constant ERC721_SYMBOL = "ZATK";
    string public constant EIP712DOMAIN_VERSION = "1";
    uint24 public constant POOL_FEE = 500; // 0.05%
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
        address account;
        VRFConfig vrfConfig;
        ERC721PermitConfig erc721PermitConfig;
        UniswapConfig uniswapConfig;
    }

    struct VRFConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2_5;
        address link;
    }

    struct ERC721PermitConfig {
        uint256 deadline;
        bytes32 eip712DomainTypeHash;
        bytes32 permitTypeHash;
        string eip712DomainName;
        string erc721Symbol;
        string eip712DomainVersion;
    }
    // https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments

    struct UniswapConfig {
        address uniswapV3Factory;
        address swapRouter02;
        uint24 poolFee;
        address usdc;
        address usdt;
        address dai;
        address weth;
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
        if (networkConfigs[chainId].vrfConfig.vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }
    /// https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-mainnet

    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        VRFConfig memory vrfConfigInfo = VRFConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            gasLane: 0x3fd2fec10d06ee8f65e7f2e95f5c56511359ece3f33960ad8a866ae24a8ff10b,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA
        });

        ERC721PermitConfig memory erc721PermitConfigInfo = ERC721PermitConfig({
            deadline: 1789716500,
            eip712DomainTypeHash: EIP712DOMAIN_TYPEHASH,
            permitTypeHash: PERMIT_TYPEHASH,
            eip712DomainName: EIP712DOMAIN_NAME,
            erc721Symbol: ERC721_SYMBOL,
            eip712DomainVersion: EIP712DOMAIN_VERSION
        });

        UniswapConfig memory uniswapConfig = UniswapConfig({
            uniswapV3Factory: UNISWAP_V3_FACTORY_MAINNET,
            swapRouter02: SWAP_ROUTER2_MAINNET,
            poolFee: POOL_FEE,
            usdc: USDC_MAINNET,
            usdt: USDT_MAINNET,
            dai: DAI_MAINNET,
            weth: WETH_MAINNET
        });

        mainnetNetworkConfig = NetworkConfig({
            account: 0x7A947bAb2A44C465760347ab9c51313d31Bcc26c,
            vrfConfig: vrfConfigInfo,
            erc721PermitConfig: erc721PermitConfigInfo,
            uniswapConfig: uniswapConfig
        });
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        VRFConfig memory vrfConfigInfo = VRFConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            // subscriptionId: 9985493892126651747780725050076838928105990851924659843866228520163437646077, // If left as 0, our scripts will create one!
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });

        ERC721PermitConfig memory erc721PermitConfigInfo = ERC721PermitConfig({
            deadline: 1789716500,
            eip712DomainTypeHash: EIP712DOMAIN_TYPEHASH,
            permitTypeHash: PERMIT_TYPEHASH,
            eip712DomainName: EIP712DOMAIN_NAME,
            erc721Symbol: ERC721_SYMBOL,
            eip712DomainVersion: EIP712DOMAIN_VERSION
        });

        UniswapConfig memory uniswapConfig = UniswapConfig({
            uniswapV3Factory: 0x0227628f3F023bb0B980b67D528571c95c6DaC1c,
            swapRouter02: 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E,
            poolFee: POOL_FEE,
            usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            usdt: 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06,
            dai: 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81
        });

        sepoliaNetworkConfig = NetworkConfig({
            account: 0x7A947bAb2A44C465760347ab9c51313d31Bcc26c,
            vrfConfig: vrfConfigInfo,
            erc721PermitConfig: erc721PermitConfigInfo,
            uniswapConfig: uniswapConfig
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (localNetworkConfig.vrfConfig.vrfCoordinatorV2_5 != address(0)) {
            return localNetworkConfig;
        }

        address vrfCoordinatorV2_5MockAddress;
        address linkTokenAddress;
        uint256 subscriptionId;
        // Check to see if we have deployed a mock contract
        try DevOpsTools.get_most_recent_deployment("VRFCoordinatorV2_5Mock", block.chainid) returns (
            address mostRecentlyDeployedVRFCoordinator
        ) {
            if (mostRecentlyDeployedVRFCoordinator != address(0)) {
                console2.log("mostRecentlyDeployedVRFCoordinator: ", mostRecentlyDeployedVRFCoordinator);
                try VRFCoordinatorV2_5Mock(mostRecentlyDeployedVRFCoordinator).getActiveSubscriptionIds(0, 1) returns (
                    uint256[] memory subscriptionids
                ) {
                    if (subscriptionids.length > 0) {
                        subscriptionId = subscriptionids[0];
                        console2.log("mostRecentlyCreated subscriptionId: ", subscriptionId);
                        (uint96 balance,, uint64 reqCount, address owner, address[] memory consumers) =
                            VRFCoordinatorV2_5Mock(mostRecentlyDeployedVRFCoordinator).getSubscription(subscriptionId);
                        console2.log("RandomNumberGenerator link balance: ", balance);
                        console2.log("RandomNumberGenerator reqCount: ", reqCount);
                        console2.log("RandomNumberGenerator owner: ", owner);
                        for (uint256 i = 0; i < consumers.length; i++) {
                            console2.log("RandomNumberGenerator consumers: ", consumers[i]);
                        }
                    }
                } catch Error(string memory reason) {
                    // 捕获revert("reasonString") 和 require(false, "reasonString")
                    console2.log("get mostRecentlyCreated subscriptionId error : ", reason);
                }

                if (subscriptionId != 0) {
                    address mostRecentlyDeployedLinkToken =
                        DevOpsTools.get_most_recent_deployment("LinkToken", block.chainid);
                    vrfCoordinatorV2_5MockAddress = mostRecentlyDeployedVRFCoordinator;
                    linkTokenAddress = mostRecentlyDeployedLinkToken;
                    console2.log("mostRecentlyDeployedLinkToken: ", mostRecentlyDeployedLinkToken);
                }
            }
        } catch Error(string memory reason) {
            // 捕获revert("reasonString") 和 require(false, "reasonString")
            console2.log("get mostRecentlyDeployedVRFCoordinator error : ", reason);
        }
        if (vrfCoordinatorV2_5MockAddress == address(0)) {
            console2.log(unicode"⚠️ You have deployed a mock conract!");
            console2.log("Make sure this was intentional");
            vm.startBroadcast(FOUNDRY_DEFAULT_SENDER);
            VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
                new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
            console2.log("create VRFCoordinatorV2_5Mock: ", address(vrfCoordinatorV2_5Mock));

            vrfCoordinatorV2_5MockAddress = address(vrfCoordinatorV2_5Mock);
            LinkToken link = new LinkToken();
            console2.log("Creating LinkToken: ", address(link));
            console2.log("FOUNDRY_DEFAULT_SENDER: %s", FOUNDRY_DEFAULT_SENDER);
            console2.log("FOUNDRY_DEFAULT_SENDER link balance: ", link.balanceOf(FOUNDRY_DEFAULT_SENDER));
            console2.log("FOUNDRY_DEFAULT_SENDER ETH balance: ", FOUNDRY_DEFAULT_SENDER.balance);
            // uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
            // console2.log("Your subscription Id is: ", subscriptionId);
            //本地直接调用fundSubscription 修改balance  线上合约没有这个方法
            // vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, 1 ether);
            linkTokenAddress = address(link);
            subscriptionId = 0;
            vm.stopBroadcast();
        }

        VRFConfig memory vrfConfigInfo = VRFConfig({
            subscriptionId: subscriptionId,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesn't really matter
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: vrfCoordinatorV2_5MockAddress,
            link: linkTokenAddress
        });

        ERC721PermitConfig memory erc721PermitConfigInfo = ERC721PermitConfig({
            deadline: 1789716500,
            eip712DomainTypeHash: EIP712DOMAIN_TYPEHASH,
            permitTypeHash: PERMIT_TYPEHASH,
            eip712DomainName: EIP712DOMAIN_NAME,
            erc721Symbol: ERC721_SYMBOL,
            eip712DomainVersion: EIP712DOMAIN_VERSION
        });
        vm.startBroadcast(FOUNDRY_DEFAULT_SENDER);
        ERC20Mock usdc = new ERC20Mock("USDC", "USDC");
        ERC20Mock usdt = new ERC20Mock("USDT", "USDT");
        ERC20Mock dai = new ERC20Mock("DAI", "DAI");
        vm.stopBroadcast();
        console2.log("usdc mock: ", address(usdc));
        console2.log("usdt mock: ", address(usdt));
        console2.log("dai mock: ", address(dai));

        UniswapConfig memory uniswapConfig = UniswapConfig({
            uniswapV3Factory: UNISWAP_V3_FACTORY_MAINNET,
            swapRouter02: SWAP_ROUTER2_MAINNET,
            poolFee: POOL_FEE,
            usdc: address(usdc),
            usdt: address(usdt),
            dai: address(dai),
            weth: WETH_MAINNET
        });

        localNetworkConfig = NetworkConfig({
            account: FOUNDRY_DEFAULT_SENDER,
            vrfConfig: vrfConfigInfo,
            erc721PermitConfig: erc721PermitConfigInfo,
            uniswapConfig: uniswapConfig
        });
        // vm.deal(localNetworkConfig.account, 100 ether);

        networkConfigs[LOCAL_CHAIN_ID] = localNetworkConfig;
        return localNetworkConfig;
    }
}
