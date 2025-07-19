// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// cast interface src/RandomNumberGenerator.sol:RandomNumberGenerator > IVRFv2PlusSubscriptionManager.txt
interface IVRFv2PlusSubscriptionManager {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function SUBSCRIBER_ROLE() external view returns (bytes32);
    function acceptOwnership() external;
    function getRandowNumbers(address _user) external view returns (uint256[] memory);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getSubscription(uint256 subId)
        external
        view
        returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers);
    function grantRole(bytes32 role, address account) external;
    function grantSubscriberRole(address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function owner() external view returns (address);
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
    function requestIdToSender(uint256) external view returns (address);
    function requestRandomWords() external returns (uint256);
    function revokeRole(bytes32 role, address account) external;
    function s_subscriptionId() external view returns (uint256);
    function s_vrfCoordinator() external view returns (address);
    function senderToNumWords(address) external view returns (uint32);
    function senderToRandomNumbers(address, uint256) external view returns (uint256);
    function setCoordinator(address _vrfCoordinator) external;
    function setSenderNumWords(uint32 _numWords) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function transferOwnership(address to) external;
}
