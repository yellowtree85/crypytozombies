// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Permit} from "./ERC721Permit.sol";
import {IERC721Permit} from "./interfaces/IERC721Permit.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter02, IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// forge inspect src/NFTMarket.sol:NFTMarket abi --json > NFTMarket.json

contract NFTMarket is IERC721Receiver, Ownable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NFTMarket__sellerListsEmpty();
    error NFTMarket__sellerListsDataError();
    error NFTMarket__feeNotSupport();
    error NFTMarket__listIdNotExist();
    error NFTMarket__msgValueIsZero();
    error NFTMarket__incorrectEthAmount();
    error NFTMarket__tokenPriceMustGreaterThanZero();
    error NFTMarket__tokenAlreadSelled(address tokenAddress, uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public immutable i_uniswapV3Factory;
    ISwapRouter02 public immutable i_uniswap_router;
    address public immutable i_weth;

    // 支持的定价代币（如 USDC、DAI、USDT 等）
    address public s_primaryPaymentToken;
    uint24 public s_poolFee;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address priceToken; // 定价代币地址
        uint256 price; // 定价代币数量
    }

    mapping(uint256 => Listing) public s_listings;
    mapping(address => uint256[]) public s_sellerLists;
    uint256 public s_listingId;

    constructor(address _uniswapV3Factory, address _router, address _weth, address _primaryToken, uint24 _poolFee)
        Ownable(msg.sender)
    {
        i_uniswapV3Factory = _uniswapV3Factory;
        i_uniswap_router = ISwapRouter02(_router);
        i_weth = payable(_weth);
        s_primaryPaymentToken = _primaryToken;
        s_listingId = 0;
        s_poolFee = _poolFee;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// 设置手续费
    function setPoolFee(uint24 _fee) external onlyOwner {
        uint24[] memory fees = new uint24[](4);
        fees[0] = 100; // 0.01%
        fees[1] = 500; // 0.05%
        fees[2] = 3000; // 0.3%
        fees[3] = 10000; // 1%
        bool isExist = false;
        for (uint256 i = 0; i < fees.length; i++) {
            if (fees[i] == _fee) {
                isExist = true;
                break;
            }
        }
        if (!isExist) {
            revert NFTMarket__feeNotSupport();
        }
        s_poolFee = _fee;
    }
    /// 上架NFT

    function permitList(
        address _nftToken,
        uint256 _tokenID,
        uint256 _price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (IERC721(_nftToken).ownerOf(_tokenID) != msg.sender) {
            revert NFTMarket__tokenAlreadSelled(_nftToken, _tokenID);
        }
        // require(IERC721(_nftToken).ownerOf(_tokenID) == msg.sender, "already selled");
        if (_price == 0) {
            revert NFTMarket__tokenPriceMustGreaterThanZero();
        }
        s_listings[s_listingId] = Listing({
            seller: msg.sender,
            nftContract: _nftToken,
            tokenId: _tokenID,
            priceToken: s_primaryPaymentToken,
            price: _price
        });

        s_sellerLists[msg.sender].push(s_listingId);

        s_listingId += 1;

        IERC721Permit(_nftToken).permit(address(this), _tokenID, deadline, v, r, s);

        // 上架NFT 将某个地址的NFT 传到Market合约地址里
        IERC721(_nftToken).safeTransferFrom(msg.sender, address(this), _tokenID, "");
    }

    /// 下架NFT
    function listRemove(uint256 _listId) external {
        Listing memory listing = s_listings[_listId];
        require(listing.seller == msg.sender, "not your listing");

        uint256[] memory _sellerLists = s_sellerLists[msg.sender];
        if (_sellerLists.length == 0) {
            revert NFTMarket__sellerListsEmpty();
        } else if (_sellerLists.length == 1) {
            if (_sellerLists[0] != _listId) {
                revert NFTMarket__sellerListsDataError();
            }
            delete s_sellerLists[msg.sender];
        } else {
            for (uint256 i = 0; i < _sellerLists.length; i++) {
                if (_sellerLists[i] == _listId) {
                    s_sellerLists[msg.sender][i] = _sellerLists[_sellerLists.length - 1];
                    s_sellerLists[msg.sender].pop();
                    break;
                }
            }
        }
        delete s_listings[_listId];
        // 转移 NFT 给卖家
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);
    }

    function buyNFT(
        uint256 listingId,
        address paymentToken, // 用户支付的代币地址
        uint256 paymentAmount // 用户支付的代币数量
    ) external payable nonReentrant {
        Listing memory listing = s_listings[listingId];
        uint256 listTokenId = listing.tokenId;
        address seller = listing.seller;

        if (seller == address(0)) {
            revert NFTMarket__listIdNotExist();
        }

        // 清除上架记录 防止重入
        uint256[] memory _sellerLists = s_sellerLists[seller];
        if (_sellerLists.length == 0) {
            revert NFTMarket__sellerListsEmpty();
        } else if (_sellerLists.length == 1) {
            if (_sellerLists[0] != listingId) {
                revert NFTMarket__sellerListsDataError();
            }
            delete s_sellerLists[seller];
        } else {
            // DOS Vulnerability
            for (uint256 i = 0; i < _sellerLists.length; i++) {
                if (_sellerLists[i] == listingId) {
                    s_sellerLists[seller][i] = _sellerLists[_sellerLists.length - 1];
                    s_sellerLists[seller].pop();
                    break;
                }
            }
        }
        delete s_listings[listingId];

        // 处理原生 ETH 支付
        if (paymentToken == address(0)) {
            if (msg.value == 0) {
                revert NFTMarket__msgValueIsZero();
            }
            if (msg.value != paymentAmount) {
                revert NFTMarket__incorrectEthAmount();
            }
            // 将 ETH 包装为 WETH
            WETH(payable(i_weth)).deposit{value: msg.value}();
            paymentToken = i_weth;
        } else {
            // 转移 ERC20 代币到合约
            // need to approve first
            TransferHelper.safeTransferFrom(paymentToken, msg.sender, address(this), paymentAmount);
        }

        // 执行代币兑换（如果需要）
        address targetToken = listing.priceToken;
        if (paymentToken != targetToken) {
            uint256 amountOut = _swapToken(paymentToken, targetToken, paymentAmount, listing.price);
            if (amountOut > listing.price) {
                TransferHelper.safeTransfer(targetToken, payable(msg.sender), amountOut - listing.price);
            }
        }

        // 转移 NFT 给买家
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listTokenId);

        // uint256 finalAmount = IERC20(targetToken).balanceOf(address(this));
        // IERC20(targetToken).transfer(payable(listing.seller), finalAmount - fee);
        // 向卖家支付（扣除手续费）
        uint256 fee = listing.price * 2 / 100; // 2% 手续费
        TransferHelper.safeTransfer(targetToken, payable(seller), listing.price - fee);
    }

    function _swapToken(address inputToken, address outputToken, uint256 inputAmount, uint256 amountOutMin)
        internal
        returns (uint256 amountOut)
    {
        // 授权 Uniswap 使用代币
        TransferHelper.safeApprove(inputToken, address(i_uniswap_router), inputAmount);

        if (inputToken == i_weth || outputToken == i_weth) {
            amountOut = swapExactInputSingle(
                inputToken,
                outputToken,
                inputAmount,
                amountOutMin,
                address(this) // 接收兑换后的代币
            );
        } else {
            // 设置兑换路径
            address[] memory path = new address[](3);
            path[0] = inputToken;
            path[1] = i_weth; // 通过 WETH 中转
            path[2] = outputToken;
            // 执行兑换
            amountOut = swapExactInputMultihop(
                inputAmount,
                amountOutMin,
                path,
                address(this) // 接收兑换后的代币
            );
        }
    }

    /// @notice swapExactOutputSingle swaps a minimum possible amount of DAI for a fixed amount of WETH.
    /// @dev The calling address must approve this contract to spend its DAI for this function to succeed. As the amount of input DAI is variable,
    /// the calling address will need to approve for a slightly higher amount, anticipating some variance.
    function swapExactInputSingle(
        address inputToken,
        address outputToken,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) internal returns (uint256 amountOut) {
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: inputToken,
            tokenOut: outputToken,
            fee: s_poolFee,
            recipient: to,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = i_uniswap_router.exactInputSingle(params);
    }

    /// @notice swapInputMultiplePools swaps a fixed amount of DAI for a maximum possible amount of WETH9 through an intermediary pool.
    /// For this example, we will swap DAI to USDC, then USDC to WETH9 to achieve our desired output.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    function swapExactInputMultihop(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to)
        internal
        returns (uint256 amountOut)
    {
        // Multiple pool swaps are encoded through bytes called a `path`. A path is a sequence of token addresses and poolFees that define the pools used in the swaps.
        // The format for pool encoding is (tokenIn, fee, tokenOut/tokenIn, fee, tokenOut) where tokenIn/tokenOut parameter is the shared token across the pools.
        // Since we are swapping DAI to USDC and then USDC to WETH9 the path encoding is (DAI, 0.3%, USDC, 0.3%, WETH9).
        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: abi.encodePacked(path[0], s_poolFee, path[1], s_poolFee, path[2]),
            recipient: to,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin
        });

        // Executes the swap.
        amountOut = i_uniswap_router.exactInput(params);
    }

    function getListsBySeller(address _seller) external view returns (uint256[] memory) {
        return s_sellerLists[_seller];
    }

    function getListDetailsById(uint256 _listId) external view returns (Listing memory) {
        return s_listings[_listId];
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
