// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct Pool {
    address lender;
    address loanToken;
    address collateralToken;
    uint256 minLoanSize;
    uint256 poolBalance;
    uint256 maxLoanRatio;
    uint256 auctionLength;
    uint256 interestRate;
    uint256 outStandingLoans;
}

struct Loan {
    address lender;
    address borrower;
    address loanToken;
    address collateralToken;
    uint256 debt;
    uint256 collateral;
    uint256 interestRate;
    uint256 auctionStartTimeStamp;
    uint256 loanStartTimeStamp;
    uint256 auctionLength;
}

struct Borrow {
    bytes32 poolId;
    uint256 debt;
    uint256 collateral;
}

struct Refinance {
    uint256 loanId;
    bytes32 poolId;
    uint256 debt;
    uint256 collateral;
}
