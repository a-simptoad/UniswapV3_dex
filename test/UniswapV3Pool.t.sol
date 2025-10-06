// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV3Pool} from "src/UniswapV3Pool.sol";
import {ERC20Mintable} from "test/ERC20Mintable.sol";
import {IUniswapV3MintCallback} from "src/interfaces/IUniswapV3MintCallback.sol";

contract UniswapV3PoolTest is Test, IUniswapV3MintCallback{
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool shouldTransferInCallback;
        bool mintLiquidity;
    }
    bool shouldTransferInCallback;

    address owner = makeAddr("owner");
    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);
        
        uint256 expectedAmount0 = 0.99897661834742528 ether;
        uint256 expectedAmount1 = 5000 ether;

        assertEq(poolBalance0, expectedAmount0, "Incorrect token0 deposited Amount");
        assertEq(poolBalance1, expectedAmount1, "Incorrect token1 deposited Amount");
    }

    function setupTestCase(TestCaseParams memory params) internal returns (uint256 poolBalance0, uint256 poolBalance1) {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(address(token0), address(token1), params.currentSqrtP, params.currentTick);

        if(params.mintLiquidity) {
            (poolBalance0, poolBalance1) = pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity);
        }

        shouldTransferInCallback = params.shouldTransferInCallback;
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) external override{
        if(shouldTransferInCallback) {
            console.log("This callback function is called");
            token0.transfer(msg.sender, amount0);
            token1.transfer(msg.sender, amount1);
        }
    }
}