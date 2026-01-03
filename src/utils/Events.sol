// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./DataTypes.sol";

event OFPL__PoolBalanceUpdated(bytes32 indexed poolId, uint256 indexed newPoolBalance, uint256 indexed updatedAt);

event OFPL__PoolCreated(Pool indexed pool,bytes32 indexed poolId, uint256 indexed createdAt);

event OFPL__PoolUpdated(bytes32 indexed poolId, uint256 indexed updatedAt);

event OFPL__LoanCreatedSuccessfully(Loan indexed loan,bytes32 poolId,uint256 indexed loanId,uint256  createdAt);

event OFPL__LoanRepaySuccessfull(uint256 indexed loanId,uint256 indexed repayedAt);

event OFPL__LoanLenderChanged(uint256 indexed loanId,bytes32 indexed oldPoolId,bytes32 indexed newPoolId);

// event OFPL__LaonIsUpdated(Loan indexed newloan,uint256 indexed updatedAt);
event OFPL__LaonIsUpdated(uint256 indexed loanId,uint256 indexed updatedAt);

event OFPL__AuctionStarted(uint256 indexed loanId,uint256 indexed startedAt);

event OFPL__LoanSeized(uint256 indexed loanId,uint256 indexed seizedAt);

event OFPL__TokenAllowListUpdated(address indexed tokenAddress,bool indexed isAllowed,uint256 indexed updatedAt);
