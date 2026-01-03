// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OFPL} from "../src/OFPL.sol";
import {FaucetToken} from "../src/FaucetToken.sol";

contract AddAllowedToken is Script {
    OFPL c_ofpl;
    function run() public {
        vm.startBroadcast();
        c_ofpl = OFPL(0xc8AC841B70ABB20ABFF81e610C1459584e32383a);
        address[10] memory tokens = [
            0x61e101bA661c151042E96340514AD210D13A541C,
            0xd401F418f15F734e05CC5015DD303e8262F8C368,
            0x7f5226367954BB30AFc0DB5f12827C67CA6353e9,
            0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F,
            0xf75b06eF8c9D77fc838d3903331E3587D2C4aeF6,
            0x9c08e0058922B22eFd75e9fc0b7fB9615e303720,
            0x48362EF49d0fc86CbEbF2445684cCA2D925e01d8,
            0x23C542AA639c3D91112818D6da6Ee60289C6bfE3,
            0xd0D02e7eF9c3eecee5e62E5E421DFC19c67AC6B4,
            0x05526D81979e0D80304aC64ED5690EAD3d9FfA76
        ];

        for (uint256 i; i < tokens.length; ++i) {
            c_ofpl.whitelistToken(tokens[i], true);
        }

        vm.stopBroadcast();
    }
}
