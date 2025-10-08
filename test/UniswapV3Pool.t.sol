// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import {Test} from "forge-std/Test.sol";
// import {UniswapV3Pool} from "src/UniswapV3Pool.sol";
// import {ERC20Mintable} from "test/ERC20Mintable.sol";
// import {IUniswapV3MintCallback} from "src/interfaces/IUniswapV3MintCallback.sol";
// import {IUniswapV3SwapCallback} from "src/interfaces/IUniswapV3SwapCallback.sol";

// contract UniswapV3PoolTest is Test, IUniswapV3MintCallback, IUniswapV3SwapCallback {
//     ERC20Mintable token0;
//     ERC20Mintable token1;
//     UniswapV3Pool pool;

//     struct TestCaseParams {
//         uint256 wethBalance;
//         uint256 usdcBalance;
//         int24 currentTick;
//         int24 lowerTick;
//         int24 upperTick;
//         uint128 liquidity;
//         uint160 currentSqrtP;
//         bool shouldTransferInCallback;
//         bool mintLiquidity;
//     }

//     bool shouldTransferInCallback;

//     address owner = makeAddr("owner");

//     function setUp() public {
//         token0 = new ERC20Mintable("Ether", "ETH", 18);
//         token1 = new ERC20Mintable("USDC", "USDC", 18);
//     }

//     function testMintSuccess() public {
//         TestCaseParams memory params = TestCaseParams({
//             wethBalance: 1 ether,
//             usdcBalance: 5000 ether,
//             currentTick: 85176,
//             lowerTick: 84222,
//             upperTick: 86129,
//             liquidity: 1517882343751509868544,
//             currentSqrtP: 5602277097478614198912276234240,
//             shouldTransferInCallback: true,
//             mintLiquidity: true
//         });

//         (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

//         uint256 expectedAmount0 = 0.99897661834742528 ether;
//         uint256 expectedAmount1 = 5000 ether;
//         assertEq(poolBalance0, expectedAmount0, "Invalid token0 Amount Minted");
//         assertEq(poolBalance1, expectedAmount1, "Invalid token1 Amount Minted");

//         assertEq(token0.balanceOf(address(pool)), poolBalance0);
//         assertEq(token1.balanceOf(address(pool)), poolBalance1);

//         (bool lowerInitialized, uint128 lowerTickLiquidity) = pool.ticks(params.lowerTick);
//         (bool upperInitialized, uint128 upperTickLiquidity) = pool.ticks(params.upperTick);
//         assertTrue(lowerInitialized);
//         assertTrue(upperInitialized);
//         assertEq(lowerTickLiquidity, params.liquidity);
//         assertEq(upperTickLiquidity, params.liquidity);

//         bytes32 PositionKey = keccak256(abi.encodePacked(address(this), params.lowerTick, params.upperTick));
//         uint128 posLiquidity = pool.positions(PositionKey);
//         assertEq(posLiquidity, params.liquidity);

//         (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
//         assertEq(sqrtPriceX96, 5602277097478614198912276234240, "invalid current sqrtP");
//         assertEq(tick, 85176, "invalid current tick");
//         assertEq(pool.liquidity(), 1517882343751509868544, "invalid current liquidity");
//     }

//     function setupTestCase(TestCaseParams memory params)
//         internal
//         returns (uint256 poolBalance0, uint256 poolBalance1)
//     {
//         token0.mint(address(this), params.wethBalance);
//         token1.mint(address(this), params.usdcBalance);

//         pool = new UniswapV3Pool(address(token0), address(token1), params.currentSqrtP, params.currentTick);
//         shouldTransferInCallback = params.shouldTransferInCallback;

//         if (params.mintLiquidity) {
//             (poolBalance0, poolBalance1) =
//                 pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity);
//         }
//     }

//     function testSwapBuyEth() public {
//         TestCaseParams memory params = TestCaseParams({
//             wethBalance: 1 ether,
//             usdcBalance: 5000 ether,
//             currentTick: 85176,
//             lowerTick: 84222,
//             upperTick: 86129,
//             liquidity: 1517882343751509868544,
//             currentSqrtP: 5602277097478614198912276234240,
//             shouldTransferInCallback: true,
//             mintLiquidity: true
//         });

//         // Adds liquidity to the pool (starting tokens to the pool)
//         (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

//         uint256 userBalance0Before = token0.balanceOf(address(this));

//         // Contract needs 42 usdc to make swap
//         token1.mint(address(this), 42 ether);

//         // Initiating the swap
//         (int256 amount0Delta, int256 amount1Delta) = pool.swap(address(this));

//         assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH out");
//         assertEq(amount1Delta, 42 ether, "invalid USDC in");

//         // checks to ensure tokens are transferred from the user
//         assertEq(
//             token0.balanceOf(address(this)), (userBalance0Before - uint256(amount0Delta)), "invalid user ETH balance"
//         );
//         assertEq(token1.balanceOf(address(this)), 0, "invalid user USDC balance");

//         // checks to ensure tokens are sent to the pool contract
//         assertEq(
//             token0.balanceOf(address(pool)), uint256(int256(poolBalance0) + amount0Delta), "invalid pool ETH balance"
//         );
//         assertEq(
//             token1.balanceOf(address(pool)), uint256(int256(poolBalance1) + amount1Delta), "invalid pool USDC balance"
//         );

//         // Checks for pool state update
//         (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
//         assertEq(sqrtPriceX96, 5604469350942327889444743441197, "invalid current sqrtP");
//         assertEq(tick, 85184, "invalid current tick");
//         assertEq(pool.liquidity(), 1517882343751509868544, "invalid current liquidity");
//     }

//     function uniswapV3MintCallback(uint256 amount0, uint256 amount1) external override {
//         if (shouldTransferInCallback) {
//             token0.transfer(msg.sender, amount0);
//             token1.transfer(msg.sender, amount1);
//         }
//     }

//     function uniswapV3SwapCallback(int256 amount0, int256 amount1) external override {
//         if (amount0 > 0) {
//             token0.transfer(msg.sender, uint256(amount0));
//         }

//         if (amount1 > 0) {
//             token0.transfer(msg.sender, uint256(amount1));
//         }
//     }
// }
