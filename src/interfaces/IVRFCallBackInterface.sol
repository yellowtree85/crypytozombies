// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVRFCallBackInterface {
    function vrfCallback(uint256 requestId, uint256[] calldata randomWords) external;
}
