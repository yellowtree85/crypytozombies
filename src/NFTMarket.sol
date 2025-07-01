// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721Permit} from "./ERC721Permit.sol";
import {IERC721Permit} from "./interfaces/IERC721Permit.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {WETH} from "@solmate/tokens/WETH.sol";

contract NFTMarket {
    address public immutable i_uniswap_router;
    address public immutable i_weth;

    // 支持的定价代币（如 USDC、DAI）
    address public s_primaryPaymentToken;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address priceToken; // 定价代币地址
        uint256 price; // 定价代币数量
    }

    mapping(uint256 => Listing) public listings;
    uint256 public s_listingId;

    constructor(address _router, address _weth, address _primaryToken) {
        i_uniswap_router = _router;
        i_weth = _weth;
        s_primaryPaymentToken = _primaryToken;
        s_listingId = 0;
    }

    function permitList(
        address _nftToken,
        uint256 _tokenID,
        uint256 _price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(IERC721(_nftToken).ownerOf(_tokenID) == msg.sender, "already selled");

        // 这里的spender就是银行合约地址
        listings[s_listingId] = Listing({
            seller: msg.sender,
            nftContract: address(_nftToken),
            tokenId: _tokenID,
            priceToken: s_primaryPaymentToken,
            price: _price
        });

        s_listingId += 1;
        IERC721Permit(_nftToken).permit(address(this), _tokenID, deadline, v, r, s);

        // 上架NFT 将某个地址的NFT 传到Marken合约地址里
        IERC721(_nftToken).safeTransferFrom(msg.sender, address(this), _tokenID, "");
    }
}
