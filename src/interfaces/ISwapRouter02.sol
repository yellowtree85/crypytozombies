// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

// import "@uniswap/v3-periphery/contracts/interfaces/ISelfPermit.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
// import {IV2SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV2SwapRouter.sol";
// import {IMulticallExtended} from "@uniswap/swap-router-contracts/contracts/interfaces/IMulticallExtended.sol";
// import "./IApproveAndCall.sol";

/// @title Router token swapping functionality
interface ISwapRouter02 is IV3SwapRouter {}
