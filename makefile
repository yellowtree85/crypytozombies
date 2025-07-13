-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil fundSubscription

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build fundSubscription

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install openzeppelin/openzeppelin-contracts@v5.3.0 && forge install smartcontractkit/chainlink-brownie-contracts && forge install transmissions11/solmate@v6 && forge install cyfrin/foundry-devops && forge install uniswap/v3-periphery@v1.0.0 && forge install uniswap/v3-core@v1.0.0 && forge install Uniswap/swap-router-contracts@v1.1.0

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 7
anvilSepolia :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 7 --fork-url $(SEPOLIA_RPC_URL)
anvilMainnet :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 7 --fork-url $(MAINNET_ALCHEMY_RPC_URL)
anvilMainnet2 :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 7 --fork-url https://reth-ethereum.ithaca.xyz/rpc
anvilArbiSepolia :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 7 --fork-url $(ARBITRUM_SEPOLIA_RPC_URL)
anvilHolesky :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 7 --fork-url $(HOLESKY_RPC_URL)
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvvv
FORK_SEPOLIA := --rpc-url http://localhost:8545 --account $(ACCOUNT_SEPOLIA) --broadcast --sender $(ACCOUNT_SEPOLIA)
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_SEPOLIA) --broadcast --sender $(ACCOUNT_SEPOLIA) --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network holesky,$(ARGS)),--network holesky)
	NETWORK_ARGS := --rpc-url $(HOLESKY_RPC_URL) --account $(ACCOUNT_HOLESKY) --broadcast --sender $(ACCOUNT_HOLESKY) --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network arbiSepolia,$(ARGS)),--network arbiSepolia)
    NETWORK_ARGS := --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --account $(ACCOUNT_ARBITRUM) --broadcast --sender $(ACCOUNT_ARBITRUM) --verify --etherscan-api-key $(ARBISCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployRandomNumberGenerator.s.sol:DeployRandomNumberGenerator $(NETWORK_ARGS)
deploySepliaFork:
	@forge script script/DeployRandomNumberGenerator.s.sol:DeployRandomNumberGenerator $(FORK_SEPOLIA)

deployZombie:
	@forge script script/DeployZombieAttack.s.sol:DeployZombieAttack $(NETWORK_ARGS)
deployNFTMarket:
	@forge script script/DeployNFTMarket.s.sol:DeployNFTMarket $(NETWORK_ARGS)
createRandomZombie:
	@forge script script/InteractionsZombies.s.sol:CreateRandomZombie $(NETWORK_ARGS)
verify-contract:
	@forge verify-contract $(CONTRACT_ADDRESS) src/Raffle.sol:Raffle --etherscan-api-key $(ETHERSCAN_API_KEY) --rpc-url $(SEPOLIA_RPC_URL) --show-standard-json-input > Raffle.json
