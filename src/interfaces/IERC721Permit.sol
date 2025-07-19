// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

///
/// @dev Interface for token permits for ERC-721
///
interface IERC721Permit is IERC165 {
    /// ERC165 bytes to add to interface array - set in parent contract
    ///
    /// _INTERFACE_ID_ERC4494 = 0x5604e225

    /// @notice Approve of a specific token ID for spending by spender via signature
    /// @param spender The account that is being approved
    /// @param tokenId The ID of the token that is being approved for spending
    /// @param deadline The deadline timestamp by which the call must be mined for the approve to work
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        payable;

    /// @notice Returns the nonce of an NFT - useful for creating permits
    /// @param tokenId the index of the NFT to get the nonce of
    /// @return the uint256 representation of the nonce
    function nonces(uint256 tokenId) external view returns (uint256);
}
