// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IVRFCallBackInterface} from "src/interfaces/IVRFCallBackInterface.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract RandomNumberGenerator is VRFConsumerBaseV2Plus, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error RandomNumberGenerator__OnlyVrfCoordinatorCanCall();
    error RandomNumberGenerator__NumWordsMustGreaterThanZero();
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RequestedRandomData(uint256 indexed requestId);
    event FulfillRandomData(address indexed sender, uint256 requestId, uint256[] randomWords);
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// Chainlink VRF Variables

    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 public s_subscriptionId;
    mapping(address => uint32) public senderToNumWords;

    mapping(uint256 => address) public requestIdToSender;
    mapping(address => uint256[]) public senderToRandomNumbers;

    // Access Control Variables
    bytes32 public constant SUBSCRIBER_ROLE = keccak256("SUBSCRIBER_ROLE");

    constructor(uint256 _subscriptionId, bytes32 _keyHash, uint32 _callbackGasLimit, address _vrfCoordinatorV2Plus)
        VRFConsumerBaseV2Plus(_vrfCoordinatorV2Plus)
    {
        s_subscriptionId = _subscriptionId;
        i_keyHash = _keyHash;
        i_callbackGasLimit = _callbackGasLimit;
    }

    function grantSubscriberRole(address account) public onlyOwner {
        _grantRole(SUBSCRIBER_ROLE, account);
    }

    function setSenderNumWords(uint32 _numWords) external onlyRole(SUBSCRIBER_ROLE) {
        if (_numWords == 0) {
            revert RandomNumberGenerator__NumWordsMustGreaterThanZero();
        }
        senderToNumWords[msg.sender] = _numWords;
    }

    function requestRandomWords() external onlyRole(SUBSCRIBER_ROLE) returns (uint256) {
        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: senderToNumWords[msg.sender],
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        requestIdToSender[requestId] = msg.sender;
        emit RequestedRandomData(requestId);
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        if (msg.sender != address(s_vrfCoordinator)) {
            revert RandomNumberGenerator__OnlyVrfCoordinatorCanCall();
        }
        address sender = requestIdToSender[requestId];
        senderToRandomNumbers[sender] = randomWords;

        if (sender.code.length > 0) {
            IVRFCallBackInterface(sender).vrfCallback(requestId, randomWords);
        }
        emit FulfillRandomData(sender, requestId, randomWords);
    }

    /**
     * @dev getRandowNumbers from vrf
     * @param _user the sender of request to vrf
     */
    function getRandowNumbers(address _user) external view returns (uint256[] memory) {
        return senderToRandomNumbers[_user];
    }
}
