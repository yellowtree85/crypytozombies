// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract DevOpsHelper {
    function getDeployment(string memory contractName, uint256 chainId) external view returns (address) {
        return DevOpsTools.get_most_recent_deployment(contractName, chainId);
    }
}
