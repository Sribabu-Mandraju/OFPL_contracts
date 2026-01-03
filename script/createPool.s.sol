// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OFPL} from "../src/OFPL.sol";
import {FaucetToken} from "../src/FaucetToken.sol";
import "../src/utils/DataTypes.sol";

contract CreatePool is Script {
    OFPL c_ofpl;

    function run() public {
        vm.startBroadcast();
        FaucetToken(0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F).mint(
            0x4c9b70b6cC1FcFd2Aaa41d705FbB9BB962BE0245,
            1000000 * 1e18
        );
        FaucetToken(0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F).approve(
            0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B,
            1000000 * 1e18
        );
        Pool memory newPool = Pool({
            lender: 0x4c9b70b6cC1FcFd2Aaa41d705FbB9BB962BE0245,
            loanToken: 0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F,
            collateralToken: 0x61e101bA661c151042E96340514AD210D13A541C,
            minLoanSize: 20 * 1e18,
            poolBalance: 1000000 * 1e18,
            maxLoanRatio: 1000 * 1e18,
            auctionLength: 2 days,
            interestRate: 1000,
            outStandingLoans: 0
        });
        c_ofpl = OFPL(0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B);
        c_ofpl.createPool(newPool);
        vm.stopBroadcast();
    }
}

contract UpdatePool is Script {
    OFPL c_ofpl;
    function run() public {
        vm.startBroadcast();
        FaucetToken(0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F).mint(
             0x4c9b70b6cC1FcFd2Aaa41d705FbB9BB962BE0245,
            100000 * 1e18
        );
        FaucetToken(0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F).approve(
            0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B,
            100000 * 1e18
        );
        c_ofpl = OFPL(0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B);

        (,,,,,,,,uint256 outStandingLoans) = c_ofpl.pools(0x83bd38c209257695bfc796761a87e4fa3e5b1e3d813b3691f8afb470d24ee456);

        Pool memory pool = Pool({
            lender: 0xa0e87A70AE6652B5727217b8CCA43898Cb02f56e,
            loanToken: 0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F,
            collateralToken: 0x61e101bA661c151042E96340514AD210D13A541C,
            minLoanSize: 40 * 1e18,
            poolBalance: 100000 * 1e18,
            maxLoanRatio: 1000 * 1e18,
            auctionLength: 2 days,
            interestRate: 1000,
            outStandingLoans: outStandingLoans
        });
        
        c_ofpl.updatePool(pool);
    }
}


contract RemoveFromPool is Script {
    OFPL c_ofpl;
    function run() public {
        vm.startBroadcast();
        c_ofpl = OFPL(0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B);
        c_ofpl.removeFromPool(0x0a5833e7d465669255dd43689326ec557b1371f2bd45bdee2be00b3ae6c384f5,100 * 1e6);
        vm.stopBroadcast();
    }
}

contract AddToPool is Script {
    OFPL c_ofpl;

    function run() public {
        vm.startBroadcast();
        FaucetToken(0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F).mint(
            0xa0e87A70AE6652B5727217b8CCA43898Cb02f56e,
            10000 * 1e18
        );
        FaucetToken(0x1627bb547C9ce9A9DdB7010807880cCd46BDa91F).approve(
            0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B,
            10000 * 1e18
        );

        c_ofpl = OFPL(0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B);
        c_ofpl.addToPool(0x0a5833e7d465669255dd43689326ec557b1371f2bd45bdee2be00b3ae6c384f5,10000 * 1e18);
        vm.stopBroadcast();
    }
}


contract TakeLoan is Script {
    OFPL c_ofpl;
    function run() public {
        vm.startBroadcast();
        FaucetToken(0x61e101bA661c151042E96340514AD210D13A541C).mint(0x4c9b70b6cC1FcFd2Aaa41d705FbB9BB962BE0245,4*1e18);
        FaucetToken(0x61e101bA661c151042E96340514AD210D13A541C).approve(0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B,4*1e18);
        c_ofpl = OFPL(0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B);
        Borrow memory b = Borrow({
            poolId:0x83bd38c209257695bfc796761a87e4fa3e5b1e3d813b3691f8afb470d24ee456,
            debt:100 * 1e18,
            collateral:4 * 1e18
        });
        c_ofpl.borrow(b);
        vm.stopBroadcast();
    }
}


contract GiveLoan is Script {
    OFPL c_ofpl;
    function run() public {
        vm.startBroadcast();
        c_ofpl = OFPL(0x1d5f2De119C1014a22fbF3D962e402FbdaD9b61B);
        Loan memory lb = c_ofpl.getLoanInfo(0);
        console.log("lender before : ",lb.lender);
        c_ofpl.giveLoan(0,0x83bd38c209257695bfc796761a87e4fa3e5b1e3d813b3691f8afb470d24ee456);
        Loan memory la = c_ofpl.getLoanInfo(0);
        console.log("lender after : ",la.lender);
        vm.stopBroadcast();

    }
}
