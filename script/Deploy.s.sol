// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OFPL} from "../src/OFPL.sol";
import {FaucetToken} from "../src/FaucetToken.sol";

contract Deploy is Script {
    OFPL c_ofpl;
    uint256 borrowerfee = 2000;
    uint256 lenderfee = 500 ;
    // FaucetToken weth;
    // FaucetToken usdc;
    // FaucetToken usdt;
    // FaucetToken dai ;
    // FaucetToken wbtc;
    // FaucetToken link;
    // FaucetToken uni ;
    // FaucetToken aave;
    // FaucetToken mkr ;
    // FaucetToken shib;

    address FeeReceiver = 0xa0e87A70AE6652B5727217b8CCA43898Cb02f56e;


    function run() public {
        vm.startBroadcast();
        // weth = new FaucetToken("Wrapped Ether", "WETH", 18);
        // usdc = new FaucetToken("USD Coin", "USDC", 6);
        // usdt = new FaucetToken("Tether USD", "USDT", 6);
        // dai  = new FaucetToken("Dai Stablecoin", "DAI", 18);
        // wbtc = new FaucetToken("Wrapped Bitcoin", "WBTC", 8);
        // link = new FaucetToken("Chainlink", "LINK", 18);
        // uni  = new FaucetToken("Uniswap", "UNI", 18);
        // aave = new FaucetToken("Aave", "AAVE", 18);
        // mkr  = new FaucetToken("Maker", "MKR", 18);
        // shib = new FaucetToken("Shiba Inu", "SHIB", 18);
        c_ofpl = new OFPL(FeeReceiver,borrowerfee,lenderfee);
        vm.stopBroadcast();
        // console.log("weth : ",address(weth));
        // console.log("usdc : ",address(usdc));
        // console.log("usdt : ",address(usdt));
        // console.log("dai : ",address(dai));
        // console.log("wbtc : ",address(wbtc));
        // console.log("link : ",address(link));
        // console.log("uni : ",address(uni));
        // console.log("aave : ",address(aave));
        // console.log("mkr : ",address(mkr));
        // console.log("ship : ",address(shib));
        console.log("OFPL protocol : ",address(c_ofpl));
    }
}
