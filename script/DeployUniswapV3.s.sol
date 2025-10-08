// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {UniswapV3Pool} from "src/UniswapV3Pool.sol";
import {UniswapV3Manager} from "src/UniswapV3Manager.sol";
import {ERC20Mintable} from "script/ERC20Mintable.sol";

contract DeployUniswapV3 is Script {
    uint256 wethBalance = 1 ether;
    uint256 usdcBalance = 5042 ether;
    int24 currentTick = 85176;
    uint160 currentSqrtP = 5602277097478614198912276234240;
    function run() external returns (UniswapV3Pool, UniswapV3Manager) {
        vm.startBroadcast();
        ERC20Mintable token0 = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable token1 = new ERC20Mintable("USD Coin", "USDC", 18);

        UniswapV3Pool pool = new UniswapV3Pool(address(token0), address(token1), currentSqrtP, currentTick);
        UniswapV3Manager manager = new UniswapV3Manager();

        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);
        vm.stopBroadcast();

        console.log("WETH address", address(token0));
        console.log("USDC address", address(token1));
        console.log("Pool address", address(pool));
        console.log("Manager address", address(manager));
    }
}