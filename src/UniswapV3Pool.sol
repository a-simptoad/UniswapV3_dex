// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Tick} from "src/libs/Tick.sol";
import {Position} from "src/libs/Position.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV3MintCallback} from "src/interfaces/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "src/interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Pool {
    // Errors
    error Pool__invalidTickRange();
    error Pool__ZeroLiquidity();
    error Pool__InsufficientInputAmount();

    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using TickBitmap for mapping(int16 => uint256);

    // constant and immutable variables are stored in contract's bytecode and hence takes less gas fees to read
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    // First variable to be stored in contract storage and hence makes it efficient to navigate price ultimately reducing gas fees.
    struct Slot0 {
        // current sqrt(P) Q64.96
        uint160 sqrtPriceX96;
        // Current tick
        int24 tick;
    }

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    // Earlier defined variables were constants hence don't take the initial memory slot
    // Hence the initial slot is reserved for keeping the price to reduce computation and gas fees
    Slot0 public slot0;

    uint128 public liquidity;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;
    // Takes the position of the word and gives out the word
    mapping(int16 => uint256) public tickBitmap;

    event Mint(
        address caller,
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address caller,
        address recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    constructor(address _token0, address _token1, uint160 sqrtPriceX96, int24 _tick) {
        token0 = _token0;
        token1 = _token1;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: _tick}); // Initialize the price and tick
    }

    /**
     * @notice Mint function is called to provide liquidty to the pool contract
     * @param owner Owner's address -> To track the owner of the liquidity provider
     * @param lowerTick Lower bound of the price range
     * @param upperTick Upper bound of the price range
     * @param amount Amount of liquidty owner provides
     *
     * @return amount0 Amount of token0 that LP provides
     * @return amount1 Amount of token1 that LP provides
     *
     * @dev Here, User specifies Liquidty and not actual token amounts as input; The contract only implements core logic
     * and hence later on a helper contract will convert token amounts to liquidity before calling this function.
     */
    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount, bytes calldata data)
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
        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        // HARD-CODED VALUES OF INPUT AMOUNTS FROM THE USER
        amount0 = 0.99897661834742528 ether;
        amount1 = 5000 ether;

        liquidity += uint128(amount);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        /// @notice We call the uniswapV3MintCallback method on the caller (Router Contract)
        /// @dev Expected that the caller is a contract and implements the uniswapV3MintCallback method and transfers tokens to this Pool contract
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        if (amount0 > 0 && balance0Before + amount0 > balance0()) revert Pool__InsufficientInputAmount();
        if (amount1 > 0 && balance1Before + amount1 > balance1()) revert Pool__InsufficientInputAmount();

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function swap(address recipient, bytes calldata data) external returns (int256 amount0, int256 amount1) {
        amount0 = -0.008396714242162444 ether; // contract pool swaps this amount to user
        amount1 = 42 ether; // User pays 45 usdc to the contract pool

        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        // Contract sends token to the recipient and lets caller transfer the input

        IERC20(token0).transfer(recipient, uint256(-amount0));

        uint256 balance1Before = balance1();
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
        if (balance1Before + uint256(amount1) < balance1()) {
            revert Pool__InsufficientInputAmount();
        }

        emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }

    function flipTick(mapping(int16 => uint256) storage self, int24 tick, int24 tickSpacing) internal {
        require(tick % tickSpacing == 0);
        // Getting the word position which contains the tick
        // The bitPos is the position of the tick in the word
        (int16 wordPos, uint bitPos) = position(tick / tickSpacing);
        // Mask is a number that has a single flag 1 set at the bit position of the tick
        // This operator here is the left bit operator which shifts the number 1 left bitPos times. Making the 1 at the bit position of the 256 bit number 1 (0x000000....001)
        uint256 mask = 1 << bitPos;
        // Then the XOR operator is applied with the word at the word position and the mask which flips the bit at the bit position.
        self[wordPos] ^= mask;
    }

    /// @dev Calculates the next initialized tick -> left one when buying token x in the same same word 
    /// @param self This is the word mapping or bitmap which contains the words with each bit as the tick index
    /// @param lte lte is the flag that sets the direction. When true, we’re selling token x and searching for the next initialized tick to the right of the current one. When false, it’s the other way around
    function nextInitializedTickWithinOneWord(mapping(int16 => uint256) storage self, int24 tick, int24 tickSpacing, bool lte) internal view returns (int24 next, bool initialized) {
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        if(lte){
            for(uint256 i = 0; i < 256; i++){
                bitPos = uint8(uint24((tick + tickSpacing * i) % 256));

                // We need to use the & bitwise operator to check if the flag is 1 at the new bitPos. 
                uint256 mask = 1 << bitPos; 
                if((self[wordPos] & mask) == mask) { // bit at bitPos = 1
                    next = tick + tickSpacing * i;
                    return (next, true);
                }
            }
        }else{
            for(uint256 i = 0; i < 256; i++){
                bitPos = uint8(uint24((tick - tickSpacing * i) % 256));

                // We need to use the & bitwise operator to check if the flag is 1 at the new bitPos. 
                uint256 mask = 1 << bitPos; 
                if((self[wordPos] & mask) == mask) { // bit at bitPos = 1
                    next = tick + tickSpacing * i;
                    return (next, true);
                }
            }
        }
        // self[wordPos] gives the word which has 256 ticks as bits.         
    }

    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        // wordPos is calculated by the right shift bitwise operator which basically divides the tick by 2**256
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick % 256));
    }
}
