// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./interfaces/IERC721Permit.sol";

abstract contract ERC721Permit is IERC721Permit, ERC721, EIP712 {
    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    using ECDSA for bytes32;

    mapping(uint256 => uint256) private _nonces;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");

    function nonces(uint256 tokenId) external view virtual override returns (uint256) {
        return _nonces[tokenId];
    }

    // function transferFrom(address from, address to, uint256 tokenId) public virtual override {
    //     _nonces[tokenId]++;
    //     super.transferFrom(from, to, tokenId);
    // }
    /**
     * @dev "消费nonce": 返回 `owner` 当前的 `nonce`，并增加 1。
     */
    function _useNonce(uint256 _tokenId) internal virtual returns (uint256) {
        return _nonces[_tokenId]++;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Permit).interfaceId || super.supportsInterface(interfaceId);
    }

    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        payable
        override
    {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenId, _useNonce(tokenId), deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);

        address owner = ownerOf(tokenId);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }
        _approve(spender, tokenId, owner);
    }

    // message we expect to have been signed
    function getMessageHash(address _spender, uint256 _tokenId, uint256 _deadline)
        public
        view
        virtual
        returns (bytes32)
    {
        return
            _hashTypedDataV4(keccak256(abi.encode(PERMIT_TYPEHASH, _spender, _tokenId, _nonces[_tokenId], _deadline)));
    }
}
