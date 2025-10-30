// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Tick {
    struct Info {
        bool initialized;
        uint128 liquidity; // default -> 0
    }

    /**
     *
     * @param self Refers to the mapping defined in the calling contract, Hence used the keyword storage.
     * @param tick tick to initialize
     * @param liqudityDelta amount of liquidity to change
     * @dev tickInfo -> defined as a storage variable as the reference self[tick] is on a storage variable in the calling
     * contract and hence to modify in the parent contract storage is used. Memory is for temp use cases
     */
    function update(mapping(int24 => Tick.Info) storage self, int24 tick, uint128 liqudityDelta) internal returns(bool flipped){
        Tick.Info storage tickInfo = self[tick];
        uint128 liquidityBefore = tickInfo.liquidity;
        uint128 liquidityAfter = liquidityBefore + liqudityDelta;

        if (liquidityBefore == 0) {
            tickInfo.initialized = true;
        }

        tickInfo.liquidity = liquidityAfter;

        flipped = (liquidityAfter == 0) != (liquidityBefore == 0);
    }
}
