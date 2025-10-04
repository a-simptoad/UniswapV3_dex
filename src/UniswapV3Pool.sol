// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Tick} from "./lib/Tick.sol";
import {Position} from "./lib/Position.sol";

contract UniswapV3Pool {
    // Errors
    error Pool__invalidTickRange();
    error Pool__ZeroLiquidity();
    error Pool__InsufficientInputAmount();

    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    struct Slot0 {
        // current sqrt(P) Q64.96
        uint160 sqrtPriceX96;
        // Current tick
        int24 tick;
    }

    // Earlier defined variables were constants hence don't take the initial memory slot
    // Hence the initial slot is reserved for keeping the price to reduce computation and gas fees
    Slot0 public slot0;

    uint128 public liquidity;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    event Mint(address sender, address owner, int24 lowerTick, int24 upperTick, uint128 amount, uint256 amount0, uint256 amount1);

    constructor(address _token0, address _token1, uint160 sqrtPriceX96, int24 _tick) {
        token0 = _token0;
        token1 = _token1;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: _tick}); // Initialize the price and tick
    }

    /**
     * @notice Mint function is called to provide liquidty to the pool contract
     * @param owner Owner's address -> To track the owner of the liquidity
     * @param lowerTick Lower bound of the price range
     * @param upperTick Upper bound of the price range
     * @param amount Amount of liquidty owner provides
     * @return amount0
     * @return amount1
     * @dev Here, User specifies Liquidty and not actual token amounts as input; The contract only implements core logic
     * and hence later on a helper contract will convert token amounts to liquidity before calling this function.
     */
    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // Checks
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert Pool__invalidTickRange();
        if (amount == 0) revert Pool__ZeroLiquidity();

        // Updating the ticks and positions mappings

        // Initializes ticks at the price ranges
        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);
        
        // Similarily initialized a position and updates the liquidity between the ticks (defines price range)
        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick
        );
        position.update(amount);

        // HARD-CODED VALUES OF INPUT AMOUNTS FROM THE USER
        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        liquidity += uint128(amount);

        uint256 balance0Before;
        uint256 balance1Before;
        if(amount0 > 0) balance0Before = balance0();
        if(amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1
        );
        if(amount0 > 0 && balance0Before + amount0 > balance0()) revert Pool__InsufficientInputAmount();
        if(amount1 > 0 && balance1Before + amount1 > balance1()) revert Pool__InsufficientInputAmount();

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function balance0() internal returns (uint256 balance){
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance){
        balance = IERC20(token1).balanceOf(address(this));
    }
}
