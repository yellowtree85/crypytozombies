// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {ZombieAttack} from "../src/ZombieAttack.sol";
import {ZombieFactory} from "../src/ZombieFactory.sol";
import {ZombieFeeding, IKittyInterface} from "../src/ZombieFeeding.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RandomNumberGenerator} from "src/RandomNumberGenerator.sol";
import {DeployRandomNumberGenerator} from "script/DeployRandomNumberGenerator.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployZombieAttack} from "script/DeployZombieAttack.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import "forge-std/Vm.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC721Permit} from "src/interfaces/IERC721Permit.sol";
import {DeployNFTMarket} from "script/DeployNFTMarket.s.sol";
import {NFTMarket} from "src/NFTMarket.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

uint256 constant DNA_DIGITS = 16;
uint256 constant DNA_MODULUS = 10 ** DNA_DIGITS;
address constant KITTY_CONTRACT_ADDRESS = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;
uint256 constant LEVEL_UP_FEE = 0.001 ether;

/// cast interface src/ZombieAttack.sol:ZombieAttack > ZombieAttackInterface.json
/// forge coverage --report debug > coverage.txt
/// forge coverage --fork-url $INFURA_MAINNET_URL --report lcov > coverage.lcov

// forge test --via-ir --mc ZombieAttactTest --fork-url $INFURA_MAINNET_URL
contract ZombieAttactTest is Test {
    ZombieAttack public zombieAttack;

    address owner;
    address attacker = makeAddr("attacker");

    HelperConfig public helperConfig;
    RandomNumberGenerator public randomNumberGenerator;
    address public randomNumberGenerator2;
    address public constant FOUNDRY_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 internal signerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal signerPrivateKey2 = 0x7c58cf190fe72d1fbcdf1dd22f71b26839a6d7e8e3320ea6d9108e4e921d7ee8;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    address linkToken;

    uint256 deadline;
    bytes32 eip712DomainTypeHash;
    bytes32 permitTypeHash;

    string eip712DomainName;
    string erc721Symbol;
    string eip712DomainVersion;
    uint256 tokenId;
    uint256 nonce;

    address usdc;
    address usdt;
    address dai;

    NFTMarket public nftMarket;

    function setUp() public {
        if (block.chainid == 31337) {
            vm.roll(1);
            // vm.deal(FOUNDRY_DEFAULT_SENDER, 100 ether);
        }
        // if (block.chainid != 1) {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory defaultConfig = helper.getConfig();
        owner = defaultConfig.account;
        linkToken = defaultConfig.vrfConfig.link;
        deal(linkToken, owner, 10 ether);
        vm.deal(owner, 100 ether);

        DeployRandomNumberGenerator deployer = new DeployRandomNumberGenerator();
        (randomNumberGenerator, helperConfig) = deployer.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.vrfConfig.subscriptionId;
        gasLane = config.vrfConfig.gasLane;
        callbackGasLimit = config.vrfConfig.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfConfig.vrfCoordinatorV2_5;

        deadline = config.erc721PermitConfig.deadline;
        eip712DomainTypeHash = config.erc721PermitConfig.eip712DomainTypeHash;
        permitTypeHash = config.erc721PermitConfig.permitTypeHash;
        eip712DomainName = config.erc721PermitConfig.eip712DomainName;
        erc721Symbol = config.erc721PermitConfig.erc721Symbol;
        eip712DomainVersion = config.erc721PermitConfig.eip712DomainVersion;

        DeployZombieAttack zombieDeployer = new DeployZombieAttack();
        // test cann't using file info because it's just a simulation
        zombieAttack = zombieDeployer.deploy(address(randomNumberGenerator), owner);

        DeployNFTMarket nftMarketDeployer = new DeployNFTMarket();
        nftMarket = nftMarketDeployer.run();
        vm.deal(attacker, 100 ether);
        // } else {
        //     owner = makeAddr("owner");
        //     randomNumberGenerator2 = makeAddr("randomNumberGenerator2");
        // }

        usdt = config.uniswapConfig.usdt;
        usdc = config.uniswapConfig.usdc;
    }

    /// forge inspect src/ZombieAttack.sol:ZombieAttack storage --json > ZombieAttack.json
    /// cast interface src/ZombieAttack.sol:ZombieAttack --json > ZombieAttackInterface.json
    /// forge test --mt testCreateRandomZombie
    function testCreateRandomZombie() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.stopPrank();

        assertEq(zombieAttack.balanceOf(owner), 1, "Owner should have 1 zombie");
        (string memory name, uint256 dna, uint32 level, uint32 readyTime, uint16 winCount, uint16 lossCount) =
            zombieAttack.s_zombies(0);
        assertEq(keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Zombie1")), true);
        assertLt(dna, 10 ** 16, "Zombie DNA should be less than 10^16");
        assertGt(readyTime, block.timestamp, "Zombie should be ready in the future");
        assertEq(level, 1, "Zombie level should be 1");
        assertEq(winCount, 0, "Zombie win count should be 0");
        assertEq(lossCount, 0, "Zombie loss count should be 0");
        assertEq(
            keccak256(abi.encodePacked(zombieAttack.getAllZombies()[0].name)) == keccak256(abi.encodePacked("Zombie1")),
            true
        );
        assertEq(zombieAttack.ownerOf(0), owner, "Owner should be the owner of the zombie");
    }

    /// forge test --mt testGetAllZombies
    function testGetAllZombies() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.stopPrank();

        ZombieFactory.Zombie[] memory s_zombies = zombieAttack.getAllZombies();
        assertEq(s_zombies.length, 1, "There should be 1 zombies");
        assertEq(keccak256(abi.encodePacked(s_zombies[0].name)) == keccak256(abi.encodePacked("Zombie1")), true);
    }

    /// forge test --mt testCreateRandomZombieFail
    function testCreateRandomZombieFail() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.expectRevert(ZombieFactory.ZombieFactory__AlreadyHaveZombie.selector);
        zombieAttack.createRandomZombie("Zombie2");
        vm.stopPrank();
    }

    /// forge test --mt testSetKittyContractAddress
    function testSetKittyContractAddress() public {
        vm.startPrank(owner);
        zombieAttack.setKittyContractAddress(KITTY_CONTRACT_ADDRESS);
        vm.stopPrank();

        // Check if the kitty contract address is set correctly
        (address kittyContract) = zombieAttack.getKittyContractAddress();
        assertEq(kittyContract, KITTY_CONTRACT_ADDRESS, "Kitty contract address should be set correctly");
    }

    function testSetKittyContractAddressFail() public {
        vm.startPrank(attacker);
        // vm.expectRevert(Ownable.OwnableUnauthorizedAccount.selector);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        zombieAttack.setKittyContractAddress(KITTY_CONTRACT_ADDRESS);
        vm.stopPrank();
    }

    /// forge test --mt testFeedAndMultiply --fork-url $INFURA_MAINNET_URL
    /// cast call 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d "getKitty(uint256)" 1 --rpc-url $INFURA_MAINET_URL
    /// cast --to-dec 5ad2b318e6724ce4b9290146531884721ad18c63298a5308a55ad6b6b58d
    /// 626837621154801616088980922659877168609154386318304496692374110716999053
    function testFeedAndMultiply() public {
        if (block.chainid != 1) {
            return;
        }
        // vm.createSelectFork("mainnet");
        vm.deal(owner, 100 ether);
        vm.startPrank(owner);
        zombieAttack = new ZombieAttack("ZombieAttack", "ZATK", randomNumberGenerator2);
        zombieAttack.createRandomZombie("Zombie1");
        zombieAttack.setKittyContractAddress(KITTY_CONTRACT_ADDRESS);
        vm.stopPrank();
        assertEq(zombieAttack.getKittyContractAddress(), KITTY_CONTRACT_ADDRESS, "Kitty contract address should be set");

        uint256 _kittyId = 1; // Example Kitty ID 5ad2b318e6724ce4b9290146531884721ad18c63298a5308a55ad6b6b58d
        IKittyInterface kittyContract = IKittyInterface(KITTY_CONTRACT_ADDRESS);
        (,,,,,,,,, uint256 _targetDna) = kittyContract.getKitty(_kittyId);

        console2.log("Target Kitty DNA: %s", _targetDna);
        _targetDna = _targetDna % DNA_MODULUS; // Example DNA
        ZombieFactory.Zombie memory zombie1 = zombieAttack.getAllZombies()[0];
        uint256 newDna = (zombie1.dna + _targetDna) / 2;
        newDna = newDna - newDna % 100 + 99;

        // vm.expectRevert();
        vm.warp(block.timestamp + 1 days);
        vm.prank(owner);
        zombieAttack.feedOnKitty(0, _kittyId);

        ZombieFactory.Zombie memory newZombie = zombieAttack.getAllZombies()[1];
        assertEq(keccak256(abi.encodePacked(newZombie.name)), keccak256(abi.encodePacked("NoName")));
        assertEq(newZombie.level, 1, "New zombie level should be 1");
        assertEq(newZombie.winCount, 0, "New zombie win count should be 0");
        assertEq(newZombie.lossCount, 0, "New zombie loss count should be 0");
        assertEq(newZombie.dna, newDna, "New zombie DNA should be less than 10^16");
    }

    /// forge test --mt testSetLevelUpFee
    function testSetLevelUpFee() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        uint256 newFee = 0.002 ether;
        zombieAttack.setLevelUpFee(newFee);
        assertEq(zombieAttack.getAllZombies()[0].level, 1);
        vm.stopPrank();
        // Check if the level up fee is set correctly
        zombieAttack.levelUp{value: newFee}(0);
        (,, uint32 level,,,) = zombieAttack.s_zombies(0);
        assertEq(level, 2, "Level up fee should be set correctly");
    }

    /// forge test --mt testChangeZombieName
    function testChangeZombieName() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        zombieAttack.levelUp{value: LEVEL_UP_FEE}(0);
        string memory newName = "NewZombieName";
        zombieAttack.changeName(0, newName);
        vm.stopPrank();

        (string memory name,,,,,) = zombieAttack.s_zombies(0);
        assertEq(
            keccak256(abi.encodePacked(name)), keccak256(abi.encodePacked(newName)), "Zombie name should be changed"
        );
    }

    /// forge test --mt testChangeZombieNameFail
    function testChangeZombieNameFail() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        // zombieAttack.levelUp{value:LEVEL_UP_FEE}(0);
        vm.expectRevert();
        zombieAttack.changeName(0, "NewZombieName");
        vm.stopPrank();
    }

    /// forge test --mt testOwnerWithdraw
    function testOwnerWithdraw() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.stopPrank();

        assertEq(address(zombieAttack).balance, 0);
        uint256 ownerStartBalance = address(owner).balance;

        vm.startPrank(attacker);
        zombieAttack.levelUp{value: LEVEL_UP_FEE}(0);
        assertEq(address(zombieAttack).balance, LEVEL_UP_FEE);
        vm.stopPrank();

        vm.startPrank(owner);
        zombieAttack.withdraw();
        vm.stopPrank();
        assertEq(address(zombieAttack).balance, 0);
        assertEq(owner.balance, ownerStartBalance + LEVEL_UP_FEE, "Owner should have received the level up fee");
    }

    /// forge test --mt testChangeZombieDna
    function testChangeZombieDna() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        for (uint256 i = 0; i < 20; i++) {
            zombieAttack.levelUp{value: LEVEL_UP_FEE}(0);
        }
        (,, uint32 level,,,) = zombieAttack.s_zombies(0);
        assertEq(level, 21);
        uint256 newDna = 1234567890123456; // Example new DNA
        zombieAttack.changeDna(0, newDna);
        vm.stopPrank();

        assertEq(zombieAttack.getAllZombies()[0].dna, newDna, "Zombie DNA should be changed");
    }

    /// forge test --mt testChangeZombieDnaFail
    function testChangeZombieDnaFail() public {
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        for (uint256 i = 1; i < 19; i++) {
            zombieAttack.levelUp{value: LEVEL_UP_FEE}(0);
        }
        assertEq(zombieAttack.getAllZombies()[0].level, 19);
        uint256 newDna = 1234567890123456; // Example new DNA
        vm.expectRevert();
        zombieAttack.changeDna(0, newDna);
        vm.stopPrank();
    }

    /// forge test --mt testGetZombiesByOwner --fork-url $INFURA_MAINNET_URL
    function testGetZombiesByOwner() public {
        if (block.chainid != 1) {
            return;
        }
        // vm.createSelectFork("mainnet");
        vm.deal(owner, 100 ether);
        vm.startPrank(owner);
        zombieAttack = new ZombieAttack("ZombieAttack", "ZATK", randomNumberGenerator2);
        zombieAttack.createRandomZombie("Zombie1");
        zombieAttack.setKittyContractAddress(KITTY_CONTRACT_ADDRESS);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        uint256 _kittyId = 1; // Example Kitty ID
        vm.prank(owner);
        zombieAttack.feedOnKitty(0, _kittyId);

        uint256[] memory zombiesByOwner = zombieAttack.getZombiesByOwner(owner);
        assertEq(zombiesByOwner.length, 2, "Owner should have 2 zombies");
        assertEq(zombiesByOwner[0], 0, "First zombie ID should be 0");
        assertEq(zombiesByOwner[1], 1, "Second zombie ID should be 1");
    }

    /// forge test --mt testZombieAttack
    function testZombieAttack() public {
        vm.prank(owner);
        zombieAttack.createRandomZombie("Zombie1");

        vm.prank(attacker);
        zombieAttack.createRandomZombie("AttackerZombie");

        uint256 zombie1Id = 0;
        uint256 attackerZombieId = 1;

        // Owner attacks attacker
        vm.expectRevert();
        zombieAttack.attack(zombie1Id, attackerZombieId);

        // Attacker attacks owner
        vm.expectRevert();
        zombieAttack.attack(attackerZombieId, zombie1Id);

        // attacks another zombie
        vm.warp(block.timestamp + 1 days); // Ensure zombie is ready
        vm.startPrank(owner);
        vm.recordLogs();
        zombieAttack.attack(zombie1Id, attackerZombieId); //// emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs
        vm.stopPrank();

        // (uint96 startbalance,,,,) = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).getSubscription(subscriptionId);
        // console2.log("Current LINK balance:", startbalance);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            uint256(requestId), address(randomNumberGenerator)
        );

        (,, uint32 level, uint32 readyTime, uint16 winCount, uint16 lossCount) = zombieAttack.s_zombies(zombie1Id);
        (, uint256 dna2,,, uint16 winCount2, uint16 lossCount2) = zombieAttack.s_zombies(attackerZombieId);
        // if win
        if (level > 1) {
            assertEq(level, 2, "Zombie level should be 2 after winning the attack");
            assertEq(winCount, 1, "Zombie win count should be 1 after winning the attack");
            assertEq(lossCount2, 1);

            ZombieAttack.AttackInfo memory attackInfo = zombieAttack.getAttackInfo(owner);
            assertEq(attackInfo.attackId, zombie1Id);
            assertEq(attackInfo.targetId, attackerZombieId);
            assertEq(attackInfo.winOrloss, true);
            assertEq(attackInfo.success, true);
            uint256 requestId2 = zombieAttack.s_attackToRequestId(owner);
            console2.log("requestId:", requestId2);
            vm.prank(owner);
            zombieAttack.winerMintZombie{value: 0.1 ether}(zombie1Id, dna2);
            console2.log("requestId:", zombieAttack.s_attackToRequestId(owner));
            // false, false, 0, 0, 0
            // (bool success, bool winOrloss, uint256 attackId, uint256 targetId, uint256 randomNum) =
            //     zombieAttack.s_requestAttackInfos(requestId);
        } else {
            assertEq(level, 1, "Zombie level should remain 1 after attack");
            assertEq(lossCount, 1, "Zombie lossCount count should  be 1 after attack");
            assertEq(winCount2, 1, "Attacker zombie loss count should be 1 after losing the attack");
            assertEq(readyTime, block.timestamp + 1 days, "Zombie should be ready after attack");
        }
    }

    function testInitialNounceNumber(uint256 _tokenID) public view {
        assertEq(zombieAttack.nonces(_tokenID), 0);
    }

    /// 本地ANVIL节点已经部署了 VRFCoordinatorV2_5Mock LinkToken 已经调用了createSubscription() 和fundSubscription(subscriptionId, 1 ether)
    /// forge test --mt testERC721PermitDomainSeparator --fork-url http://localhost:8545
    /// forge test --mt testERC721PermitDomainSeparator --fork-url $INFURA_MAINNET_URL
    function testERC721PermitDomainSeparator() public {
        // mint token to owner
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.stopPrank();

        tokenId = 0;
        nonce = zombieAttack.nonces(tokenId);
        assertEq(zombieAttack.nonces(tokenId), 0);
        assertEq(zombieAttack.balanceOf(owner), 1, "Owner should have 1 zombie");
        (string memory name,,,,,) = zombieAttack.s_zombies(tokenId);
        assertEq(keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Zombie1")), true);

        /// assembly  digest
        bytes32 domainSeparator = keccak256(
            abi.encode(
                eip712DomainTypeHash, // type hash
                keccak256(bytes(eip712DomainName)), // name
                keccak256(bytes(eip712DomainVersion)), // version
                block.chainid, // chain id
                address(zombieAttack) // contract address
            )
        );

        // 拼接 Hash
        bytes32 structHash = keccak256(abi.encode(permitTypeHash, address(nftMarket), tokenId, nonce, deadline));

        // 获取签名消息hash
        // bytes32 digest = keccak256(
        //     abi.encodePacked("\x19\x01", domainSeparator, structHash)
        // );

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        address signer = vm.addr(signerPrivateKey);
        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        vm.stopPrank();
        bytes memory signature = abi.encodePacked(r, s, v); // note the order here is different from line above.
        console2.logBytes(signature);
        console2.log("spender :", address(nftMarket));
        console2.log("tokenId: ", tokenId); // 0
        console2.log("nonce: ", nonce); //0
        console2.log("deadline", deadline); //1789716500
        console2.log("v,r,s:", v); //27
        console2.logBytes32(r); // 0x2e6fc93fa8520730c6ff4411425527a114d6f672931cd658a3dcb3b01fba2543
        console2.logBytes32(s); // 0x62fef7eefce7da0ea3b8b4f005cc9f226b2442306637f96870626ce7ece308da

        assertEq(zombieAttack.nonces(tokenId), 0);
        // vm.prank(owner);
        // IERC721Permit(address(zombieAttack)).permit(address(nftMarket), tokenId, deadline, v, r, s);
        // assertEq(zombieAttack.getApproved(tokenId), address(nftMarket));
        // assertEq(zombieAttack.nonces(tokenId), 1);

        // 上架tokenId = 0
        uint256 tokenPrice = 22 ether;
        vm.prank(owner);
        nftMarket.permitList(address(zombieAttack), tokenId, tokenPrice, deadline, v, r, s);

        assertEq(zombieAttack.ownerOf(tokenId), address(nftMarket));
        assertEq(zombieAttack.nonces(tokenId), 1);
        uint256 listId = nftMarket.getListsBySeller(owner)[0];
        NFTMarket.Listing memory list = nftMarket.getListDetailsById(listId);
        console2.log("listId:", listId);
        console2.log("seller:", list.seller);
        console2.log("nftContract;:", list.nftContract);
        console2.log("tokenID:", list.tokenId);
        console2.log("priceToken:", list.priceToken); //USDT 0xdAC17F958D2ee523a2206206994597C13D831ec7
        console2.log("price:", list.price);
        assertEq(list.tokenId, tokenId);
        assertEq(list.price, tokenPrice);
        assertEq(list.seller, owner);
    }

    /// forge test --mt testNFTMarketListRemove --fork-url http://localhost:8545
    function testNFTMarketListRemove() public {
        // mint token to owner
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.stopPrank();

        tokenId = 0;
        nonce = zombieAttack.nonces(tokenId);
        assertEq(zombieAttack.nonces(tokenId), 0);
        assertEq(zombieAttack.balanceOf(owner), 1, "Owner should have 1 zombie");
        (string memory name,,,,,) = zombieAttack.s_zombies(tokenId);
        assertEq(keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Zombie1")), true);

        /// assembly  digest
        bytes32 domainSeparator = keccak256(
            abi.encode(
                eip712DomainTypeHash, // type hash
                keccak256(bytes(eip712DomainName)), // name
                keccak256(bytes(eip712DomainVersion)), // version
                block.chainid, // chain id
                address(zombieAttack) // contract address
            )
        );

        // 拼接 Hash
        bytes32 structHash = keccak256(abi.encode(permitTypeHash, address(nftMarket), tokenId, nonce, deadline));

        // 获取签名消息hash
        // bytes32 digest = keccak256(
        //     abi.encodePacked("\x19\x01", domainSeparator, structHash)
        // );

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        address signer = vm.addr(signerPrivateKey);
        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        vm.stopPrank();
        bytes memory signature = abi.encodePacked(r, s, v); // note the order here is different from line above.
        console2.logBytes(signature);
        console2.log("spender :", address(nftMarket));
        console2.log("tokenId: ", tokenId); // 0
        console2.log("nonce: ", nonce); //0
        console2.log("deadline", deadline); //1789716500
        console2.log("v,r,s:", v); //27
        console2.logBytes32(r); // 0x2e6fc93fa8520730c6ff4411425527a114d6f672931cd658a3dcb3b01fba2543
        console2.logBytes32(s); // 0x62fef7eefce7da0ea3b8b4f005cc9f226b2442306637f96870626ce7ece308da

        assertEq(zombieAttack.nonces(tokenId), 0);
        // 上架tokenId = 0
        uint256 tokenPrice = 22 ether;
        vm.prank(owner);
        nftMarket.permitList(address(zombieAttack), tokenId, tokenPrice, deadline, v, r, s);

        assertEq(zombieAttack.ownerOf(tokenId), address(nftMarket));
        assertEq(zombieAttack.nonces(tokenId), 1);

        uint256 listId = nftMarket.getListsBySeller(owner)[0];
        NFTMarket.Listing memory list = nftMarket.getListDetailsById(listId);
        console2.log("listId:", listId);
        console2.log("seller:", list.seller);
        console2.log("nftContract;:", list.nftContract);
        console2.log("tokenID:", list.tokenId);
        console2.log("priceToken:", list.priceToken); //USDT 0xdAC17F958D2ee523a2206206994597C13D831ec7
        console2.log("price:", list.price);
        assertEq(list.tokenId, tokenId);
        assertEq(list.price, tokenPrice);
        assertEq(list.seller, owner);

        // 下架tokenId = 0
        vm.prank(owner);
        nftMarket.listRemove(listId);

        assertEq(nftMarket.getListsBySeller(owner).length, 0);
        assertEq(nftMarket.getListDetailsById(listId).seller, address(0));
        assertEq(zombieAttack.ownerOf(tokenId), owner);
    }

    /// forge test --mt testNFTMarketETHBuyNFT --fork-url $INFURA_MAINNET_URL
    function testNFTMarketETHBuyNFT() public {
        // mint token to owner
        console2.log("owner ", owner);
        console2.log("owner.code  ");
        console2.logBytes(owner.code);
        console2.log("owner.code.length ", owner.code.length);
        // require(owner.code.length == 0, "owner is a contract");
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.stopPrank();
        console2.log("token Zombie1 owner:", zombieAttack.ownerOf(0));
        tokenId = 0;
        nonce = zombieAttack.nonces(tokenId);
        assertEq(zombieAttack.nonces(tokenId), 0);
        assertEq(zombieAttack.balanceOf(owner), 1, "Owner should have 1 zombie");

        /// assembly  digest
        bytes32 domainSeparator = keccak256(
            abi.encode(
                eip712DomainTypeHash, // type hash
                keccak256(bytes(eip712DomainName)), // name
                keccak256(bytes(eip712DomainVersion)), // version
                block.chainid, // chain id
                address(zombieAttack) // contract address
            )
        );

        // 拼接 Hash
        bytes32 structHash = keccak256(abi.encode(permitTypeHash, address(nftMarket), tokenId, nonce, deadline));

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        address signer = vm.addr(signerPrivateKey2);
        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey2, digest);
        vm.stopPrank();
        bytes memory signature = abi.encodePacked(r, s, v); // note the order here is different from line above.
        console2.logBytes(signature);
        console2.log("spender :", address(nftMarket));
        console2.log("tokenId: ", tokenId); // 0
        console2.log("nonce: ", nonce); //0
        console2.log("deadline", deadline); //1789716500
        console2.log("v,r,s:", v); //27
        console2.logBytes32(r); // 0x2e6fc93fa8520730c6ff4411425527a114d6f672931cd658a3dcb3b01fba2543
        console2.logBytes32(s); // 0x62fef7eefce7da0ea3b8b4f005cc9f226b2442306637f96870626ce7ece308da

        assertEq(zombieAttack.nonces(tokenId), 0);

        // 上架tokenId = 0
        uint256 tokenPrice = 2800 * 1e6;
        vm.prank(owner);
        nftMarket.permitList(address(zombieAttack), tokenId, tokenPrice, deadline, v, r, s);

        assertEq(zombieAttack.ownerOf(tokenId), address(nftMarket));
        assertEq(zombieAttack.nonces(tokenId), 1);

        uint256 listId = nftMarket.getListsBySeller(owner)[0];
        NFTMarket.Listing memory list = nftMarket.getListDetailsById(listId);
        console2.log("listId:", listId);
        console2.log("seller:", list.seller);
        console2.log("nftContract;:", list.nftContract);
        console2.log("tokenID:", list.tokenId);
        console2.log("priceToken:", list.priceToken); //USDT 0xdAC17F958D2ee523a2206206994597C13D831ec7
        console2.log("price:", list.price);
        assertEq(list.tokenId, tokenId);
        assertEq(list.price, tokenPrice);
        assertEq(list.seller, owner);

        // 用ETH购买NFT
        uint256 startBalance = IERC20(usdt).balanceOf(list.seller);
        vm.prank(attacker);
        nftMarket.buyNFT{value: 1 ether}(listId, address(0), 1 ether);

        assertEq(zombieAttack.ownerOf(tokenId), address(attacker));
        uint256 endBalance = IERC20(usdt).balanceOf(list.seller);
        assertEq(endBalance - startBalance, tokenPrice - (tokenPrice * 2 / 100));
        console2.log("attacker get usdt ", IERC20(usdt).balanceOf(attacker));
    }

    /// forge test --mt testNFTMarketUSDCBuyNFT --fork-url $INFURA_MAINNET_URL
    function testNFTMarketUSDCBuyNFT() public {
        // mint token to owner
        console2.log("owner ", owner);
        console2.log("owner.code  ");
        console2.logBytes(owner.code);
        console2.log("owner.code.length ", owner.code.length);
        // require(owner.code.length == 0, "owner is a contract");
        vm.startPrank(owner);
        zombieAttack.createRandomZombie("Zombie1");
        vm.stopPrank();
        console2.log("token Zombie1 owner:", zombieAttack.ownerOf(0));
        tokenId = 0;
        nonce = zombieAttack.nonces(tokenId);
        assertEq(zombieAttack.nonces(tokenId), 0);
        assertEq(zombieAttack.balanceOf(owner), 1, "Owner should have 1 zombie");

        /// assembly  digest
        bytes32 domainSeparator = keccak256(
            abi.encode(
                eip712DomainTypeHash, // type hash
                keccak256(bytes(eip712DomainName)), // name
                keccak256(bytes(eip712DomainVersion)), // version
                block.chainid, // chain id
                address(zombieAttack) // contract address
            )
        );

        // 拼接 Hash
        bytes32 structHash = keccak256(abi.encode(permitTypeHash, address(nftMarket), tokenId, nonce, deadline));

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        address signer = vm.addr(signerPrivateKey2);
        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey2, digest);
        vm.stopPrank();
        bytes memory signature = abi.encodePacked(r, s, v); // note the order here is different from line above.
        console2.logBytes(signature);
        console2.log("spender :", address(nftMarket));
        console2.log("tokenId: ", tokenId); // 0
        console2.log("nonce: ", nonce); //0
        console2.log("deadline", deadline); //1789716500
        console2.log("v,r,s:", v); //27
        console2.logBytes32(r); // 0x2e6fc93fa8520730c6ff4411425527a114d6f672931cd658a3dcb3b01fba2543
        console2.logBytes32(s); // 0x62fef7eefce7da0ea3b8b4f005cc9f226b2442306637f96870626ce7ece308da

        assertEq(zombieAttack.nonces(tokenId), 0);

        // 上架tokenId = 0
        uint256 tokenPrice = 100 * 1e6; //USDT
        vm.prank(owner);
        nftMarket.permitList(address(zombieAttack), tokenId, tokenPrice, deadline, v, r, s);

        assertEq(zombieAttack.ownerOf(tokenId), address(nftMarket));
        assertEq(zombieAttack.nonces(tokenId), 1);

        uint256 listId = nftMarket.getListsBySeller(owner)[0];
        NFTMarket.Listing memory list = nftMarket.getListDetailsById(listId);
        console2.log("listId:", listId);
        console2.log("seller:", list.seller);
        console2.log("nftContract;:", list.nftContract);
        console2.log("tokenID:", list.tokenId);
        console2.log("priceToken:", list.priceToken); //USDT 0xdAC17F958D2ee523a2206206994597C13D831ec7
        console2.log("price:", list.price);
        assertEq(list.tokenId, tokenId);
        assertEq(list.price, tokenPrice);
        assertEq(list.seller, owner);

        // 用USDC购买NFT
        uint256 startBalance = IERC20(usdt).balanceOf(list.seller);

        uint256 paymentAmount = 120 * 1e6;
        deal(usdc, attacker, paymentAmount); // 120 USDC
        console2.log("attacker usdc balance before:", IERC20(usdc).balanceOf(attacker));
        vm.prank(attacker);

        IERC20(usdc).approve(address(nftMarket), paymentAmount);
        console2.log("NFTMarket usdc allowance:", IERC20(usdc).allowance(attacker, address(nftMarket)));
        vm.prank(attacker);
        nftMarket.buyNFT(listId, usdc, paymentAmount);

        uint256 endBalance = IERC20(usdt).balanceOf(list.seller);
        assertEq(endBalance - startBalance, tokenPrice - (tokenPrice * 2 / 100));

        assertEq(zombieAttack.ownerOf(tokenId), address(attacker));
        console2.log("attacker get usdt ", IERC20(usdt).balanceOf(attacker));
    }
}
