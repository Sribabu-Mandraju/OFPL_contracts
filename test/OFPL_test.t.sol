// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/OFPL.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/utils/DataTypes.sol";


contract Token is ERC20 {
    uint8 private _decimals;

    constructor(string memory tokenName,string memory symbol,uint8 decimals_) ERC20(tokenName,symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }


    function mint(address _to,uint256 _amount) public {
        _mint(_to,_amount);
    }
}

contract OFPL_test is Test {
    OFPL c_ofpl;
    address admin = makeAddr("feeReceiver");
    address lender1 = makeAddr("lender1");
    address lender2 = makeAddr("lender2");
    address borrower1 = makeAddr("borrower1");
    address borrower2 = makeAddr("borrower2");
    address bob = makeAddr("bob");
    address feeReceiver = makeAddr("feeReceiver");
    uint256 borrowerfee = 2000;
    uint256 lenderfee = 500 ;
    // admin = feeReceiver;
    Token weth;
    Token usdc;
    Token dai;
    Token wbtc;
    Token maliciousToken;
    uint256 public immutable MAXIMUM_AUCTION_LENGTH = 3 days;
    uint256 public immutable MAXIMUM_INTEREST_RATE = 4000;
    uint256 public immutable MAXIMUM_BORROWER_FEE = 2000;
    uint256 public immutable MAXIMUM_LENDER_FEE = 5000;

    function setUp() public  {
        vm.startPrank(admin);
        weth = new Token("WETH","weth",18);
        usdc = new Token("USDC","usdc",6);
        dai = new Token("DAI","dai",18);
        wbtc = new Token("WBTC","wbtc",8);
        maliciousToken = new Token("MAL","MT",18);
        c_ofpl = new OFPL(feeReceiver,borrowerfee,lenderfee);
        vm.stopPrank();
    }


    /////////////////////// UNIT TESTING - ADMIN CONFIGURATION ///////////////////////

    function testOwner() public {
        assertEq(c_ofpl.owner() , feeReceiver);
    }

    function test_global_variables_and_immutable_variables_constructor_arguments() public {
        assertEq(c_ofpl.MAXIMUM_AUCTION_LENGTH(), MAXIMUM_AUCTION_LENGTH);
        assertEq(c_ofpl.MAXIMUM_INTEREST_RATE(),MAXIMUM_INTEREST_RATE);
        assertEq(c_ofpl.MAXIMUM_BORROWER_FEE(),MAXIMUM_BORROWER_FEE);
        assertEq(c_ofpl.MAXIMUM_LENDER_FEE(),MAXIMUM_LENDER_FEE);

        assertEq(c_ofpl.s_feeReceiver(),feeReceiver);
        assertEq(c_ofpl.s_borrowerFee(),borrowerfee);
        assertEq(c_ofpl.s_lenderFee(),lenderfee);

    }

    function test_setBorrowerFee() public {
        vm.startPrank(admin);
        uint256 newBorrowerFee = 200;
        c_ofpl.setBorroweFee(newBorrowerFee);
        assertEq(c_ofpl.s_borrowerFee(),newBorrowerFee);
        vm.stopPrank();
    }

    function test_setBorrowerFee_by_nonAdmin() public {
        uint256 newBorrowerFee = 200;
        vm.expectRevert();
        c_ofpl.setBorroweFee(newBorrowerFee);
    }

    function test_setBorrowerFee_with_zero_fee() public {
        vm.startPrank(admin);
        uint256 newBorrowerFee = 0;
        vm.expectRevert();
        c_ofpl.setBorroweFee(newBorrowerFee);
        vm.stopPrank();
    }

    function test_setBorrowerFee_with_maximumfee() public {
        vm.startPrank(admin);
        uint256 newBorrowerFee = MAXIMUM_BORROWER_FEE;
        c_ofpl.setBorroweFee(newBorrowerFee);
        vm.stopPrank();
    }

    function test_setBorrowerFee_with_moreThan_maximumfee() public {
        vm.startPrank(admin);
        uint256 newBorrowerFee = MAXIMUM_BORROWER_FEE + 1;
        vm.expectRevert();
        c_ofpl.setBorroweFee(newBorrowerFee);
        vm.stopPrank();
    }

    function test_whitelistToken() public {
        vm.startPrank(admin);
        c_ofpl.whitelistToken(address(dai), true);
        assertTrue(c_ofpl.isAllowedToken(address(dai)));
        vm.stopPrank();
    }

    function test_whitelistToken_by_nonAdmin() public {
        vm.expectRevert();
        c_ofpl.whitelistToken(address(dai), true);
    }

    function test_whitelistToken_token_with_zeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert();
        c_ofpl.whitelistToken(address(0), true);
        vm.stopPrank();
    }

    function testSetLenderFee() public {
        vm.startPrank(admin);
        c_ofpl.setLenderFee(200);
        vm.stopPrank();
    }

    function testSetLenderFee_by_nonAdmin() public {
        vm.expectRevert();
        c_ofpl.setLenderFee(200);
        
    }


    function testSetLenderFee_greater_than_maximum_fee() public {
        vm.startPrank(admin);
        vm.expectRevert();
        c_ofpl.setLenderFee(MAXIMUM_LENDER_FEE+1);
        vm.stopPrank();
    }

    function testSetLenderFee_as_zero() public {
        vm.startPrank(admin);
        vm.expectRevert();
        c_ofpl.setLenderFee(0);
        vm.stopPrank();
    }

    function testSetFeeReceiverAddress() public {
        vm.startPrank(admin);
        c_ofpl.setFeeReceiverAddress(bob);
        assertEq(bob,c_ofpl.s_feeReceiver());
        vm.stopPrank();
    }

    function testsetFeeReceiver_with_zero_address() public {
        vm.startPrank(admin);
        vm.expectRevert();
        c_ofpl.setFeeReceiverAddress(address(0));
        vm.stopPrank();
    }

    function testFeeReceiver_to_ofpl_contract() public {
        vm.startPrank(admin);
        vm.expectRevert();
        c_ofpl.setFeeReceiverAddress(address(c_ofpl));
        vm.stopPrank();

    }


    function test_createPool() public  whiteListTokens returns (bytes32){
        vm.startPrank(lender1);
        dai.mint(lender1, 100_000 * 1e18);
        dai.approve(address(c_ofpl),100_000 * 1e18 );
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:100_000 * 1e18,
            maxLoanRatio:1000 * 1e18,
            auctionLength:2 days,
            interestRate:1000,
            outStandingLoans:0
        });
        console.log("address of this contract : ",address(this));
        console.log("msg.sender",msg.sender);
        console.log("lender1",lender1);
        bytes32 poolId = c_ofpl.createPool(pool);
        

        assertEq(c_ofpl.getPoolID(pool.lender, pool.loanToken, pool.collateralToken),poolId);
        (
        address lender,
        address loanToken,
        address collateralToken,
        uint256 minLoanSize,
        uint256 poolBalance,
        uint256 maxLoanRatio,
        uint256 auctionLength,
        uint256 interestRate,
        uint256 outStandingLoans
        ) = c_ofpl.pools(poolId);
        assertEq(poolBalance,100_000*1e18);
        assertEq(outStandingLoans,0);
        assertEq(lender,lender1);
        assertEq(auctionLength,2 days);
        uint256 contractBalace = IERC20(loanToken).balanceOf(address(c_ofpl));
        assertEq(contractBalace,poolBalance);
        vm.stopPrank();
        return poolId;
    }


    function test_createPool_with_nonWhitelisted_tokens() public  whiteListTokens returns (bytes32){
        vm.startPrank(lender1);
        usdc.mint(lender1, 100_000 * 1e18);
        usdc.approve(address(c_ofpl),100_000 * 1e18 );
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(usdc),
            collateralToken:address(wbtc),
            minLoanSize:100 * 1e18,
            poolBalance:100_000 * 1e18,
            maxLoanRatio:1000 * 1e18,
            auctionLength:2 days,
            interestRate:1000,
            outStandingLoans:0
        });
        console.log("address of this contract : ",address(this));
        console.log("msg.sender",msg.sender);
        console.log("lender1",lender1);
        vm.expectRevert();
        c_ofpl.createPool(pool);
    
    }

    function test_updatePool_by_changing_loanToken() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(usdc),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:100_000 * 1e18,
            maxLoanRatio:1000 * 1e18,
            auctionLength:2 days,
            interestRate:1000,
            outStandingLoans:0
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }

    function test_updatePool_by_changing_collateralToken() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(wbtc),// chaning collateral token
            minLoanSize:100 * 1e18,
            poolBalance:100_000 * 1e18,
            maxLoanRatio:1000 * 1e18,
            auctionLength:2 days,
            interestRate:1000,
            outStandingLoans:0
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }


    function test_updatePool_by_changing_maxloanRatio_to_zero() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:100_000 * 1e18,
            maxLoanRatio:0 * 1e18, // max loan ratio is can't be zero
            auctionLength:2 days,
            interestRate:1000,
            outStandingLoans:0
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }


    function test_updatePool_by_changing_interestRate_moreThan_maximum_interest_rate() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:100_000 * 1e18,
            maxLoanRatio:1000 * 1e18,
            auctionLength:2 days,
            interestRate:5000,// interest rate is too high
            outStandingLoans:0
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }

    function test_updatePool_by_changing_auctionLength_moreThan_maxiumum_auction_length() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:100_000 * 1e18,
            maxLoanRatio:1100 * 1e18,
            auctionLength:4 days, // more then maximum auction length
            interestRate:1000,
            outStandingLoans:0
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }


    function test_updatePool_by_trying_to_updatePoolBalance() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:110_000 * 1e18, // insufficient  balance 
            maxLoanRatio:1100 * 1e18,
            auctionLength:3 days,
            interestRate:1000,
            outStandingLoans:0
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }

    function test_updatePool_by_trying_to_updatePoolBalance_with_sufficient_balance() public {
        test_createPool();
        vm.startPrank(lender1);
        dai.mint(lender1, 10_000 * 1e18);
        uint256 beforeBalance = dai.balanceOf(lender1);
        dai.approve(address(c_ofpl), 10_000 * 1e18);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:110_000 * 1e18, // sufficient  balance 
            maxLoanRatio:1100 * 1e18,
            auctionLength:3 days,
            interestRate:1000,
            outStandingLoans:0
        });

        c_ofpl.updatePool(pool);
        uint256 afterBalance = dai.balanceOf(lender1);
        assertTrue(beforeBalance > afterBalance,"no change in balance");
        assertEq(beforeBalance-afterBalance,10_000*1e18);
        vm.stopPrank();
    }



    function test_updatePool_by_changing_lender_of_the_pool() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender2, // changing lender of the contract
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:110_000 * 1e18, 
            maxLoanRatio:1100 * 1e18,
            auctionLength:3 days,
            interestRate:1000,
            outStandingLoans:0
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }

    function test_updatePool_by_changing_outStandingloan() public {
        test_createPool();
        vm.startPrank(lender1);
        Pool memory pool = Pool({
            lender:lender1,
            loanToken:address(dai),
            collateralToken:address(weth),
            minLoanSize:100 * 1e18,
            poolBalance:110_000 * 1e18,  
            maxLoanRatio:1100 * 1e18,
            auctionLength:3 days,
            interestRate:1000,
            outStandingLoans:1
        });
        vm.expectRevert();
        c_ofpl.updatePool(pool);
        vm.stopPrank();
    }


    function test_addToPool() public {
        bytes32 poolId = test_createPool();
        vm.startPrank(lender1);
        uint256 amountToAdd = 10*1e18;
        dai.mint(lender1,amountToAdd);
        dai.approve(address(c_ofpl), amountToAdd);
        (,,,,uint256 poolBalanceBefore,,,,) = c_ofpl.pools(poolId);
        c_ofpl.addToPool(poolId, amountToAdd);
        vm.stopPrank();
        (,,,,uint256 poolBalanceAfter,,,,) = c_ofpl.pools(poolId);
        assertGt(poolBalanceAfter,poolBalanceBefore);
        assertEq(poolBalanceBefore+amountToAdd,poolBalanceAfter);
    }

    function test_addToPool_adding_zero_amount() public {
        bytes32 poolId = test_createPool();
        vm.startPrank(lender1);
        dai.approve(address(c_ofpl), 0);
        vm.expectRevert();        
        c_ofpl.addToPool(poolId, 0);
        vm.stopPrank();
    }

    function test_removeFromPool() public {
        bytes32 poolId = test_createPool();
        // uint256 oldPoolBalance  = 100_000 * 1e18;
        uint256 amountToRemove = 1000 * 1e18;
        vm.startPrank(lender1);
        (,,,,uint256 poolBalanceBefore,,,,) = c_ofpl.pools(poolId);
        c_ofpl.removeFromPool(poolId, amountToRemove);
        (,,,,uint256 poolBalanceAfter,,,,) = c_ofpl.pools(poolId);
        vm.stopPrank();

        assertEq(poolBalanceAfter,poolBalanceBefore-amountToRemove);

    }


    function test_removeFromPool_moreThan_poolBalance() public {
        bytes32 poolId = test_createPool();
        (,,,,uint256 poolBalanceBefore,,,,) = c_ofpl.pools(poolId);
        vm.startPrank(lender1);
        vm.expectRevert();
        c_ofpl.removeFromPool(poolId, poolBalanceBefore+1);
        vm.stopPrank();
    }


    function test_borrow() public returns (bytes32 b_poolId,uint256 loanId) {
        b_poolId = test_createPool();
        vm.startPrank(borrower1);
        uint256 initialBalance = dai.balanceOf(borrower1);
        console.log("initial balance :",initialBalance);
        weth.mint(borrower1,1e18);
        weth.approve(address(c_ofpl),1e18);

        Borrow memory brw = Borrow({
            poolId:b_poolId,
            debt:1000 * 1e18,
            collateral:1e18
        });
        uint256 b_loanId = c_ofpl.borrow(brw);
        (
        address lender,
        address borrower,
        address loanToken,
        address collateralToken,
        uint256 debt,
        uint256 collateral,
        uint256 interestRate,
        uint256 auctionStartTimeStamp,
        uint256 loanStartTimeStamp,
        uint256 auctionLength
        ) = c_ofpl.loans(b_loanId);

        uint256 balanceAfterLoan = dai.balanceOf(borrower1);
        console.log("balance after loan :",balanceAfterLoan);
        console.log("actual debt :",debt);  
        // (,,,,uint256 poolBalanceBefore,,,,uint256 outStandingLoans) = c_ofpl.pools(brw.poolId);
        // assertEq(outStandingLoans,1000 * 1e18);
        vm.stopPrank();
    }

    function test_borrow_with_malicious_token() public  {
        bytes32 poolId = test_createPool();
        vm.startPrank(admin);
        c_ofpl.whitelistToken(address(maliciousToken), true);
        vm.stopPrank();

        vm.startPrank(borrower1);
        uint256 collateralAmount = 1e18;
        wbtc.mint(borrower1, collateralAmount);
        wbtc.approve(address(c_ofpl),collateralAmount);
        Borrow memory brw = Borrow({
            poolId:poolId,
            debt:500 * 1e18 ,
            collateral:collateralAmount
        });
        vm.expectRevert();
        c_ofpl.borrow(brw);
        vm.stopPrank();
    }


    function test_repay() public {
        (bytes32 r_poolId,uint256 r_loanId) = test_borrow();
        // console.log("pool id :",r_poolId);
        (
        address lender,
        address borrower,
        address loanToken,
        address collateralToken,
        uint256 debt,
        uint256 collateral,
        uint256 interestRate,
        uint256 auctionStartTimeStamp,
        uint256 loanStartTimeStamp,
        uint256 auctionLength
        ) = c_ofpl.loans(r_loanId);

        uint256 initialBalance = dai.balanceOf(borrower1);
        console.log("//////////// REPAY /////////////");
        console.log("initial balance : ",initialBalance);
        console.log("debt :",debt);
        uint256 loanStart = loanStartTimeStamp;
        vm.warp(loanStart + 2 days);

        assertEq(block.timestamp, loanStart + 2 days);

        uint256 expectedInterestForDebt = c_ofpl.expectedTotalDebt(r_loanId);
        console.log("total debt to pay :",debt + expectedInterestForDebt);

        vm.startPrank(borrower1);
        dai.mint(borrower1,debt + expectedInterestForDebt - initialBalance);
        uint256 totalUserBalanceToPay = dai.balanceOf(borrower1);
        console.log("balance before pay",totalUserBalanceToPay);    
        dai.approve(address(c_ofpl),totalUserBalanceToPay);
        (,,,,uint256 poolBalanceBefore,,,,uint256 outStandingLoansBefore) = c_ofpl.pools(r_poolId);
        uint256 balanceOfFeeReceiverBeforeRepay = dai.balanceOf(feeReceiver);
        c_ofpl.repay(r_loanId);

        uint256 balanceAfterPay = dai.balanceOf(borrower1);
        console.log("after pay user balance :",balanceAfterPay);
        (,,,,uint256 poolBalanceAfter,,,,uint256 outStandingLoansAfter) = c_ofpl.pools(r_poolId);
        console.log("outstanding loan after ",outStandingLoansAfter);
        console.log("pool after :",poolBalanceAfter);
        console.log("before :",outStandingLoansBefore);
        uint256 balanceOfFeeReceiverAfterRepay = dai.balanceOf(feeReceiver);
        console.log("fee receiver balance after :",balanceOfFeeReceiverAfterRepay);
        console.log("fee receiver balance before:",balanceOfFeeReceiverBeforeRepay);
        uint256 DifferenceOfFeeReceiverBalance = balanceOfFeeReceiverAfterRepay - balanceOfFeeReceiverBeforeRepay;
        uint256 poolBalanceDifference =  poolBalanceBefore + debt + expectedInterestForDebt + DifferenceOfFeeReceiverBalance - poolBalanceAfter;
        console.log("pool balance difference :",poolBalanceDifference);
        // assertEq(poolBalanceAfter ,poolBalanceBefore + debt + expectedInterestForDebt + DifferenceOfFeeReceiverBalance,"pool balance check");
        assertEq(outStandingLoansBefore,outStandingLoansAfter + debt ,"out standing loans check");

        vm.stopPrank();

    }


    // function test_giveLoan() public {
    //     (bytes32 r_poolId,uint256 r_loanId) = test_borrow();
    //     vm.startPrank(lender2);

    //     Pool memory pool = Pool({
    //         lender:lender2,
    //         loanToken:address(dai),
    //         collateralToken:address(weth),
    //         minLoanSize:100 * 1e18,
    //         poolBalance:100_000 * 1e18,
    //         maxLoanRatio:1000 * 1e18,
    //         auctionLength:2 days,
    //         interestRate:800,
    //         outStandingLoans:0
    //     });
    //     dai.mint(lender2,100_000 * 1e18);
    //     dai.approve(address(c_ofpl),100_000 * 1e18);
    //     bytes32 newPoolId = c_ofpl.createPool(pool);
        
    //     vm.stopPrank();
    //     vm.startPrank(lender1);
    //     c_ofpl.giveLoan(r_loanId, newPoolId);

    //     vm.stopPrank();
    // }


    function test_giveLoan() public {
    (bytes32 r_poolId, uint256 r_loanId) = test_borrow();

    // -------------------------------
    // Create new pool (lender2)
    // -------------------------------
    vm.startPrank(lender2);

    Pool memory pool = Pool({
        lender: lender2,
        loanToken: address(dai),
        collateralToken: address(weth),
        minLoanSize: 100 * 1e18,
        poolBalance: 100_000 * 1e18,
        maxLoanRatio: 1000 * 1e18,
        auctionLength: 2 days,
        interestRate: 800,
        outStandingLoans: 0
    });

    dai.mint(lender2, 100_000 * 1e18);
    dai.approve(address(c_ofpl), 100_000 * 1e18);
    bytes32 newPoolId = c_ofpl.createPool(pool);

    vm.stopPrank();

    // -------------------------------
    // BEFORE giveLoan
    // -------------------------------
    Loan memory loanBefore = c_ofpl.getLoanInfo(r_loanId);

    console.log("----- BEFORE giveLoan -----");
    console.log("Loan ID:", r_loanId);
    console.log("Lender:", loanBefore.lender);
    console.log("Debt:", loanBefore.debt);
    console.log("Interest Rate:", loanBefore.interestRate);

    // -------------------------------
    // Call giveLoan (lender1)
    // -------------------------------
    vm.startPrank(lender1);
    c_ofpl.giveLoan(r_loanId, newPoolId);
    vm.stopPrank();

    // -------------------------------
    // AFTER giveLoan
    // -------------------------------
    Loan memory loanAfter = c_ofpl.getLoanInfo(r_loanId);

    console.log("----- AFTER giveLoan -----");
    console.log("Lender:", loanAfter.lender);
    console.log("Debt:", loanAfter.debt);
    console.log("Interest Rate:", loanAfter.interestRate);
    console.log("Loan Start Timestamp:", loanAfter.loanStartTimeStamp);

    // -------------------------------
    // Assertions (recommended)
    // -------------------------------
    assertEq(loanAfter.lender, lender2, "Lender should be updated to new pool lender");
    assertGt(loanAfter.debt, loanBefore.debt, "Debt should increase after interest");
}



    function test_startAuction() public {
        (bytes32 r_poolId,uint256 r_loanId) = test_borrow();
        vm.startPrank(lender1);
        c_ofpl.startAuction(r_loanId);
        vm.stopPrank();
    }

    // function test_buyLoan() public {
    //     (bytes32 r_poolId,uint256 r_loanId) = test_borrow();
    //     vm.startPrank(lender1);
    //     c_ofpl.startAuction(r_loanId);
    //     vm.stopPrank();

    //     (
    //     address lender,
    //     address borrower,
    //     address loanToken,
    //     address collateralToken,
    //     uint256 debt,
    //     uint256 collateral,
    //     uint256 interestRate,
    //     uint256 auctionStartTimeStamp,
    //     uint256 loanStartTimeStamp,
    //     uint256 auctionLength
    //     ) = c_ofpl.loans(r_loanId);

    //     vm.warp(auctionStartTimeStamp + 40 hours);
    //     uint256 expectedInterestRate = c_ofpl.getExpectedAuctionInterestRate(r_loanId);
    //     console.log("expected interest rate :",expectedInterestRate);
    //     vm.startPrank(lender2);
    //     Pool memory pool = Pool({
    //         lender:lender2,
    //         loanToken:address(dai),
    //         collateralToken:address(weth),
    //         minLoanSize:100 * 1e18,
    //         poolBalance:100_000 * 1e18,
    //         maxLoanRatio:1000 * 1e18,
    //         auctionLength:2 days,
    //         interestRate:800,
    //         outStandingLoans:0
    //     });
        
    //     dai.mint(lender2,100_000 * 1e18);
    //     dai.approve(address(c_ofpl),100_000 * 1e18);
    //     bytes32 newPoolId = c_ofpl.createPool(pool);
        
    //     c_ofpl.buyLoan(r_loanId, newPoolId);
    //     (,,,,,,uint256 newInterestRate,,,) = c_ofpl.loans(r_loanId);
    //     console.log("new interest rate :",newInterestRate);
    //     vm.stopPrank();
    // }

    modifier whiteListTokens() {
        vm.startPrank(admin);
        c_ofpl.whitelistToken(address(dai), true);
        c_ofpl.whitelistToken(address(weth), true);
        vm.stopPrank();
        _;
    }

   
}