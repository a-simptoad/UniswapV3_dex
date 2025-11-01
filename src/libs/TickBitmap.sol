// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BitMath} from "./BitMath.sol";

library TickBitmap {
    function flipTick(mapping(int16 => uint256) storage self, int24 tick, int24 tickSpacing) internal {
        require(tick % tickSpacing == 0);
        // Getting the word position which contains the tick
        // The bitPos is the position of the tick in the word
        (int16 wordPos, uint256 bitPos) = position(tick / tickSpacing);
        // Mask is a number that has a single flag 1 set at the bit position of the tick
        // This operator here is the left bit operator which shifts the number 1 left bitPos times. Making the 1 at the bit position of the 256 bit number 1 (0x000000....001)
        uint256 mask = 1 << bitPos;
        // Then the XOR operator is applied with the word at the word position and the mask which flips the bit at the bit position.
        self[wordPos] ^= mask;
    }

    /// @dev Calculates the next initialized tick -> previous tick when buying token x in the same same word
    /// @param self This is the word mapping or bitmap which contains the words with each bit as the tick index
    /// @param lte lte is the flag that sets the direction. When true, we’re selling token x and searching for the next initialized tick to the left of the current one. When false, it’s the other way around
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;

            initialized = masked != 0;
            next = initialized
                ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * tickSpacing
                : (compressed - int24(uint24(bitPos))) * tickSpacing;
        } else {
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & ~mask;

            initialized = masked != 0;
            next = initialized
                ? (compressed + 1 + int24(uint24((BitMath.leastSignificantBit(masked) - bitPos)))) * tickSpacing
                : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) * tickSpacing;
        }
    }
    // Try out the buy token x implementation again keeping current word_pos and bit_pos

    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        // wordPos is calculated by the right shift bitwise operator which basically divides the tick by 2**256
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick % 256));
    }
}
