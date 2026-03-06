// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function allowance(address owner, address spender) external view returns (uint256);
}

contract AllowanceTest is Test {

    IERC20 token;

    address owner = 0x16109767fA41Da84B78A17B4878B171b37E925aC;
    address spender = 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045;

    function setUp() public {
        token = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    }

    function testPrintAllowance() public view {
        uint256 allowed = token.allowance(owner, spender);
        console.log("Allowance:", allowed);
    }
}