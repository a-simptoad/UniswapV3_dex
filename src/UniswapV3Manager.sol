// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {UniswapV3Pool} from "src/UniswapV3Pool.sol";
import {IUniswapV3MintCallback} from "src/interfaces/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "src/interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Manager is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    function mint(address pool, int24 lowerTick, int24 upperTick, uint128 liquidity, bytes calldata data) external {
        UniswapV3Pool(pool).mint(msg.sender, lowerTick, upperTick, liquidity, data);
    }

    function swap(address pool, bytes calldata data) public {
        UniswapV3Pool(pool).swap(msg.sender, data);
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external override {
        (address token0, address token1, address payer) = abi.decode(data, (address, address, address));

        // Payer will allow this contract to move amount0, amount1 amount of tokens

        // Transfers tokens from the payer to the pool contract
        IERC20(token0).transferFrom(payer, msg.sender, amount0);
        IERC20(token1).transferFrom(payer, msg.sender, amount1);
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) external override {
        (address token0, address token1, address payer) = abi.decode(data, (address, address, address));

        if (amount0 > 0) {
            IERC20(token0).transferFrom(payer, msg.sender, uint256(amount0));
        }

        if (amount1 > 0) {
            IERC20(token1).transferFrom(payer, msg.sender, uint256(amount1));
        }
    }
}
