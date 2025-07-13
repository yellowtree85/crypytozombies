// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {NFTMarket} from "src/NFTMarket.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
/// forge script script/DeployNFTMarket.s.sol --rpc-url $RPC_URL_LOCAL --private-key $DEFAULT_ANVIL_KEY --sender $ACCOUNT_LOCAL --broadcast

contract DeployNFTMarket is Script {
    NFTMarket public nftMarket;

    function run() public returns (NFTMarket) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        return deploy(
            config.account,
            config.uniswapConfig.uniswapV3Factory,
            config.uniswapConfig.swapRouter02,
            config.uniswapConfig.weth,
            config.uniswapConfig.usdt,
            config.uniswapConfig.poolFee
        );
    }

    function deploy(
        address account,
        address _uniswapV3Factory,
        address _swapRouter02,
        address weth,
        address _primaryToken,
        uint24 _poolFee
    ) public returns (NFTMarket) {
        vm.startBroadcast(account);
        nftMarket = new NFTMarket(_uniswapV3Factory, _swapRouter02, weth, _primaryToken, _poolFee);
        vm.stopBroadcast();
        return nftMarket;
    }
}
