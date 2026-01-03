// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./utils/DataTypes.sol";
import "./utils/Events.sol";
import { console} from "forge-std/Test.sol";


/// @title Decentralised Oracle Free Perpetial Lending Protocol
/// @author Sribabu Mandraju aka AVG_Spidey
/// @notice Its a Decentralised peer to peer perpetual lending protocol
/// @dev I am the developer!

contract OFPL is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    ////////////////// CONSTANT VARIABLES //////////////////

    uint256 public immutable MAXIMUM_AUCTION_LENGTH = 3 days;
    uint256 public immutable MAXIMUM_INTEREST_RATE = 4000;
    uint256 public immutable MAXIMUM_BORROWER_FEE = 2000;
    uint256 public immutable MAXIMUM_LENDER_FEE = 5000;
    uint256 internal constant REPAY_GRACE_TIME = 60;

    ////////////////// GLOBAL VARIABLES ///////////////////
    address public s_feeReceiver;
    uint256 public s_borrowerFee;
    uint256 public s_lenderFee;

    mapping(bytes32 => Pool) public pools;
    mapping(address => bool) public isAllowedToken;
    Loan[] public loans;

    constructor(
        address _feeReceiver,
        uint256 _borrowerFee,
        uint256 _lenderFee
    ) Ownable(_feeReceiver) {
        s_feeReceiver = _feeReceiver;
        s_borrowerFee = _borrowerFee;
        s_lenderFee = _lenderFee;
    }

    /////////////// GOVERNANCE FUCNTIONS ////////////////////////

    function setBorroweFee(uint256 _newBorrowerFee) external onlyOwner {
        require(_newBorrowerFee != 0,"Can't set borrower fee to zero");
        require(
            _newBorrowerFee <= MAXIMUM_BORROWER_FEE,
            "Borrower Fee too high"
        );
        s_borrowerFee = _newBorrowerFee;
    }

    function whitelistToken(
        address _tokenAddress,
        bool _value
    ) external onlyOwner {
        require(_tokenAddress != address(0),"can't whitelist zero address token");
        isAllowedToken[_tokenAddress] = _value;
        emit OFPL__TokenAllowListUpdated(_tokenAddress,_value,block.timestamp);
    }

    function setLenderFee(uint256 _newLenderFee) external onlyOwner {
        require(_newLenderFee != 0 ,"lender fee cannot be zero");
        require(_newLenderFee <= MAXIMUM_LENDER_FEE, "Lender Fee too high");
        s_lenderFee = _newLenderFee;
    }

    function setFeeReceiverAddress(address _newFeeReceiver) external onlyOwner {
        require(
            _newFeeReceiver != address(0) && _newFeeReceiver != address(this),
            "invalid address"
        );
        s_feeReceiver = _newFeeReceiver;
    }

    //////////////////// POOL CONFIGURATION ///////////////////////

    function createPool(Pool memory p) public nonReentrant returns (bytes32) {
        require(
            p.lender != address(0) &&
                isAllowedToken[p.loanToken] &&
                isAllowedToken[p.collateralToken] &&
                p.interestRate <= MAXIMUM_INTEREST_RATE &&
                p.maxLoanRatio != 0 &&
                p.auctionLength <= MAXIMUM_AUCTION_LENGTH &&
                p.minLoanSize != 0 &&
                p.outStandingLoans == 0 &&
                msg.sender == p.lender,
            "Pool configuration error"
        );
        bytes32 poolId = getPoolID(p.lender, p.loanToken, p.collateralToken);
        require(pools[poolId].lender == address(0), "pool already exists");
        pools[poolId] = p;
        IERC20(p.loanToken).safeTransferFrom(
            msg.sender,
            address(this),
            p.poolBalance
        );
        emit OFPL__PoolCreated(p,poolId, block.timestamp);
        return poolId;
    }

    function updatePool(Pool calldata p) external nonReentrant {
        bytes32 poolId = getPoolID(p.lender, p.loanToken, p.collateralToken);
        Pool storage pool = pools[poolId];

        require(p.lender == msg.sender, "unauthourized");
        require(
            pool.lender != address(0) && p.lender != address(0),
            "pool configuration error"
        );
        require(
            pool.loanToken == p.loanToken &&
                pool.collateralToken == p.collateralToken,
            "token mismatch"
        );
        require(
            pool.outStandingLoans == p.outStandingLoans,
            "pool configuration error"
        );
        require(
            p.interestRate <= MAXIMUM_INTEREST_RATE &&
                p.auctionLength <= MAXIMUM_AUCTION_LENGTH,
            "pool configuration error"
        );

        require(p.maxLoanRatio != 0,"pool configuration error");

        uint256 currentBalance = pool.poolBalance;

        if (currentBalance < p.poolBalance) {
            IERC20(p.loanToken).safeTransferFrom(
                msg.sender,
                address(this),
                p.poolBalance - currentBalance
            );
            
        } else if (currentBalance > p.poolBalance) {
            IERC20(p.loanToken).safeTransfer(
                msg.sender,
                currentBalance - p.poolBalance
            );
        }
        
        pool.poolBalance = p.poolBalance;
        pool.interestRate = p.interestRate;
        pool.minLoanSize = p.minLoanSize;
        pool.maxLoanRatio = p.maxLoanRatio;
        pool.auctionLength = p.auctionLength;
        // emit OFPL__PoolBalanceUpdated(poolId,p.poolBalance,block.timestamp);
        emit OFPL__PoolUpdated(poolId, block.timestamp);
    }

    function addToPool(bytes32 poolId, uint256 amount) public nonReentrant {
        Pool memory p = pools[poolId];
        require(p.lender == msg.sender, "unauthourized");
        require(amount != 0, "invalid amount");
        IERC20(p.loanToken).safeTransferFrom(msg.sender, address(this), amount);
        _updatePoolBalance(poolId, p.poolBalance + amount);
        uint256 newPoolBalance = pools[poolId].poolBalance;
        require(newPoolBalance > p.poolBalance, "No amount is added");
        // emit OFPL__PoolBalanceUpdated(poolId, newPoolBalance, block.timestamp);
        emit OFPL__PoolUpdated(poolId, block.timestamp);
    }

    function removeFromPool(
        bytes32 poolId,
        uint256 amount
    ) public nonReentrant {
        Pool memory p = pools[poolId];
        require(p.lender != address(0), "Pool does not exist");
        require(p.lender == msg.sender, "unauthourized");
        require(amount != 0, "zero amount");
        require(amount <= p.poolBalance, "insufficient pool balance");
        uint256 newPoolBalance = p.poolBalance - amount;
        _updatePoolBalance(poolId, newPoolBalance);
        IERC20(p.loanToken).safeTransfer(msg.sender, amount);
        // emit OFPL__PoolBalanceUpdated(poolId, newPoolBalance, block.timestamp);
        emit OFPL__PoolUpdated(poolId, block.timestamp);
    }

    ///////////////////USERS CONFIGURATION /////////////
 
    function borrow(Borrow calldata b) external nonReentrant returns (uint256 loanId){
        require(pools[b.poolId].lender != address(0), "Pool does not exist");
        Pool memory p = pools[b.poolId];
        require(b.debt <= p.poolBalance, "insufficient pool balance");
        require(b.debt >= p.minLoanSize, "loan too small");
        require(b.collateral != 0, "Zero collateral");
        
        uint256 loanRation = _getLoanRation(
            p.loanToken,
            p.collateralToken,
            b.debt,
            b.collateral
        );
        require(loanRation <= p.maxLoanRatio, "Loan ratio too high");
        

        Loan memory loan = Loan({
            lender: p.lender,
            borrower: msg.sender,
            loanToken: p.loanToken,
            collateralToken: p.collateralToken,
            debt: b.debt,
            collateral: b.collateral,
            interestRate: p.interestRate,
            auctionStartTimeStamp: type(uint256).max,
            loanStartTimeStamp:block.timestamp,
            auctionLength: p.auctionLength
        });

        uint256 newBalance = p.poolBalance-b.debt;
        _updatePoolBalance(b.poolId,newBalance);
        // emit OFPL__PoolBalanceUpdated(b.poolId,newBalance,block.timestamp);
        pools[b.poolId].outStandingLoans += b.debt;
        emit OFPL__PoolUpdated(b.poolId, block.timestamp);
        uint256 fees = (b.debt*s_borrowerFee)/10000;
        uint256 DebtAfterPayingFee = b.debt-fees;
        loanId = loans.length;
        loans.push(loan);

        IERC20(p.collateralToken).safeTransferFrom(msg.sender,address(this),b.collateral);
        
        IERC20(p.loanToken).safeTransfer(s_feeReceiver, fees);
        
        IERC20(p.loanToken).safeTransfer(msg.sender,DebtAfterPayingFee);
        
        emit OFPL__LoanCreatedSuccessfully(loan,b.poolId,loanId,block.timestamp);
    }


    function repay(uint256 loanId) external {
        require(loanId < loans.length,"invalid loan id");
        Loan memory loan = loans[loanId];
        require(loan.lender != address(0),"Loan does not exist");
        require(msg.sender == loan.borrower,"unauthourized");
        bytes32 poolId = getPoolID(loan.lender, loan.loanToken, loan.collateralToken);
        Pool storage pool = pools[poolId];
        require(pool.collateralToken == loan.collateralToken && pool.loanToken == loan.loanToken , "token mismatch");
        (uint256 lenderfee,uint256 protcolfee) = _calculateInterest(loan);
        uint256 totalDebt = loan.debt+lenderfee+protcolfee;
        uint256 newPoolBalance = pool.poolBalance + loan.debt + lenderfee;
        _updatePoolBalance(poolId, newPoolBalance);
        // emit OFPL__PoolBalanceUpdated(poolId,newPoolBalance,block.timestamp);
        pool.outStandingLoans -= loan.debt;
        emit OFPL__PoolUpdated(poolId, block.timestamp);
        IERC20(pool.loanToken).safeTransferFrom(msg.sender,address(this),totalDebt);
        IERC20(pool.loanToken).safeTransfer(s_feeReceiver,protcolfee);
        IERC20(pool.collateralToken).safeTransfer(msg.sender,loan.collateral);
        emit OFPL__LoanRepaySuccessfull(loanId,block.timestamp);
        delete loans[loanId];
    }


    function giveLoan(uint256 loanId,bytes32 poolId) external nonReentrant() {
        require(loanId < loans.length,"invalid loanid");
        Loan storage loan = loans[loanId];
        require(loan.lender != address(0),"Loan does not exist");
        require(msg.sender == loan.lender ,"unauthourized" );
        bytes32 oldPoolId = getPoolID(loan.lender, loan.loanToken, loan.collateralToken);
        Pool storage newPool = pools[poolId];
        require(loan.loanToken == newPool.loanToken,"token mismatch");
        require(loan.collateralToken == newPool.collateralToken,"token mismatch");
        // require(loan.debt > newPool.minLoanSize ,"loan too small");
        // require(loan.debt <= newPool.maxLoanRatio,"Pool too small");
        require(loan.auctionStartTimeStamp == type(uint256).max,"loan is in auction");
        require(loan.auctionLength <= newPool.auctionLength , "auction length too small");
        require(loan.interestRate >= newPool.interestRate,"interest is too high");
        (uint256 interest,uint256 protocolfee) = _calculateInterest(loan); 
        uint256 totalDebt = loan.debt+interest+protocolfee;
        require(totalDebt > newPool.minLoanSize ,"loan too small");
        require(totalDebt <= newPool.maxLoanRatio,"Pool too small");
        uint256 newBalance = pools[oldPoolId].poolBalance + loan.debt + interest;
        require(newPool.poolBalance >= totalDebt, "INSUFFICIENT_POOL_BALANCE");
        _updatePoolBalance(oldPoolId,newBalance);
        pools[oldPoolId].outStandingLoans -= loan.debt;
        // emit OFPL__PoolBalanceUpdated(oldPoolId,newBalance,block.timestamp);
        emit OFPL__PoolUpdated(oldPoolId, block.timestamp);

        uint256 newPoolBalance = newPool.poolBalance - totalDebt;
        _updatePoolBalance(poolId, newPoolBalance);
        newPool.outStandingLoans += totalDebt;
        emit OFPL__PoolUpdated(poolId, block.timestamp);
        // emit OFPL__PoolBalanceUpdated(poolId,newPoolBalance,block.timestamp);
        IERC20(loan.loanToken).safeTransfer(s_feeReceiver,protocolfee);

        loan.lender = newPool.lender;
        loan.debt = totalDebt;
        loan.loanStartTimeStamp = block.timestamp;
        loan.interestRate = newPool.interestRate;
        loan.auctionLength = newPool.auctionLength;

        emit OFPL__LoanLenderChanged(loanId,oldPoolId,poolId);
        

        emit OFPL__LaonIsUpdated(loanId,block.timestamp);


    }


  
    function startAuction(uint256 loanId) external {
        require(loanId < loans.length,"invalid loan id");
        Loan storage loan = loans[loanId];
        require(loan.lender != address(0),"Loan does not exist");
        require(msg.sender == loan.lender ,"unauthourized" );
        require(loan.auctionStartTimeStamp == type(uint256).max,"auction is already started");
        loan.auctionStartTimeStamp = block.timestamp;
        emit OFPL__AuctionStarted(loanId,block.timestamp);
    }

    function buyLoan(uint256 loanId,bytes32 poolId) external nonReentrant() {
        require(loanId < loans.length,"invalid loan id");
        Loan storage loan = loans[loanId];
        require(loan.lender != address(0),"Loan does not exist");
        require(msg.sender == pools[poolId].lender,"unauthourized");
        require(loan.auctionStartTimeStamp != type(uint256).max,"loan is not in auction");
        require(block.timestamp <= (loan.auctionStartTimeStamp + loan.auctionLength),"auctio period is completed");
        bytes32 oldPoolId = getPoolID(loan.lender, loan.loanToken, loan.collateralToken);
        Pool storage newPool = pools[poolId];
        require(loan.loanToken == newPool.loanToken,"token mismatch");
        require(loan.collateralToken == newPool.collateralToken , "token mismatch");

        (uint256 interest, uint256 protocolFee) = _calculateInterest(loan);
        uint256 totalDebt = loan.debt + interest + protocolFee;

        uint256 loanRation = _getLoanRation(loan.loanToken, loan.collateralToken, loan.debt, loan.collateral);
        require(newPool.poolBalance >= totalDebt,"pool too small");
        require(newPool.minLoanSize <= totalDebt,"loan too small");
        require(newPool.maxLoanRatio >= loanRation,"loan ratio is too high");
        require(newPool.auctionLength >= loan.auctionLength,"aution length is too small");
        
        
        uint256 currentAuctionRate = getExpectedAuctionInterestRate(loanId);
        console.log("in contract current auction rate :",currentAuctionRate);

        require(newPool.interestRate < currentAuctionRate,"interest rate is too high");
        
        _updatePoolBalance(oldPoolId, loan.debt+interest);
        pools[oldPoolId].outStandingLoans -= loan.debt;
        emit OFPL__PoolUpdated(oldPoolId, block.timestamp);
        IERC20(loan.loanToken).safeTransfer(s_feeReceiver,protocolFee);
        _updatePoolBalance(poolId, totalDebt);
        // emit OFPL__PoolBalanceUpdated(poolId,totalDebt,block.timestamp);
        pools[poolId].outStandingLoans += totalDebt;
        emit OFPL__PoolUpdated(poolId, block.timestamp);

        loan.lender = newPool.lender;
        loan.debt = totalDebt;
        loan.loanStartTimeStamp = block.timestamp;
        loan.interestRate = currentAuctionRate;
        loan.auctionLength = newPool.auctionLength;
        loan.auctionStartTimeStamp = type(uint256).max;

        emit OFPL__LaonIsUpdated(loanId,block.timestamp);
    }

    function getExpectedAuctionInterestRate(uint256 loanId)
    public
    view
    returns (uint256)
    {
        require(loanId < loans.length, "invalid loan id");
        Loan memory loan = loans[loanId];
        require(loan.lender != address(0), "loan does not exist");
        require(loan.auctionLength > 0, "invalid auction length");

        if (block.timestamp < loan.auctionStartTimeStamp) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - loan.auctionStartTimeStamp;

        if (timeElapsed >= loan.auctionLength) {
            return MAXIMUM_INTEREST_RATE;
        }

        return (MAXIMUM_INTEREST_RATE * timeElapsed) / loan.auctionLength;
    }



    function siezeLoan(uint256 loanId) external {
        require(loanId < loans.length,"invalid loan id");
        Loan storage loan = loans[loanId];
        require(loan.lender != address(0),"Loan does not exist");
        require(msg.sender == loan.lender,"unauthourized");
        require(block.timestamp > loan.auctionStartTimeStamp + loan.auctionLength,"auction is not yet ended");
        uint256 borrowerFee = (loan.collateral*s_borrowerFee)/10000;
        IERC20(loan.collateralToken).safeTransfer(s_feeReceiver,borrowerFee);
        IERC20(loan.collateralToken).safeTransfer(loan.lender,loan.collateral);

        bytes32 poolId = getPoolID(loan.lender, loan.loanToken, loan.collateralToken);

        pools[poolId].outStandingLoans -= loan.debt;
        emit OFPL__LoanSeized(loanId,block.timestamp);

    }


    function RefinanceLoan(Refinance calldata rf) external nonReentrant() {
        require(rf.loanId < loans.length,"invalid loan id");
        Loan storage loan = loans[rf.loanId];
        require(loan.lender != address(0),"Loan does not exist");
        require(msg.sender == loan.borrower,"unauthorized");
        bytes32 oldPoolId = getPoolID(loan.lender, loan.loanToken, loan.collateralToken);
        require(oldPoolId != rf.poolId,"can't refinance with same pool");
        Pool memory newPool = pools[rf.poolId];
        require(loan.loanToken == newPool.loanToken,"token mismatch");
        require(loan.auctionStartTimeStamp == type(uint256).max,"loan is in auction");
        require(loan.collateralToken == newPool.collateralToken,"token mismatch");

        uint256 newLoanRatio = _getLoanRation(loan.loanToken,loan.collateralToken,rf.debt,rf.collateral);

        require(newLoanRatio > newPool.maxLoanRatio,"loan ratio is too high");

        
        
        (uint256 interest,uint256 protocolfee) = _calculateInterest(loan);
        uint256 totalDebt = loan.debt + interest + protocolfee;

        _updatePoolBalance(oldPoolId,loan.debt + interest );
        emit OFPL__PoolBalanceUpdated(oldPoolId,loan.debt + interest,block.timestamp);
        pools[oldPoolId].outStandingLoans -= loan.debt;


        _updatePoolBalance(rf.poolId, totalDebt);
        emit OFPL__PoolBalanceUpdated(rf.poolId,totalDebt,block.timestamp);
        newPool.outStandingLoans += totalDebt;

        if(totalDebt > rf.debt){
            IERC20(loan.loanToken).safeTransferFrom(msg.sender,address(this),totalDebt-rf.debt);
        }else if(totalDebt < rf.debt){
            uint256 borrowFee = (s_borrowerFee * (rf.debt-totalDebt))/10000;
            IERC20(loan.loanToken).safeTransfer(s_feeReceiver,borrowFee);
            IERC20(loan.loanToken).safeTransfer(msg.sender,rf.debt-totalDebt);
        }

        loan.debt = rf.debt;

        if(loan.collateral > rf.collateral){
            IERC20(loan.collateralToken).safeTransfer(msg.sender,loan.collateral-rf.collateral);
        }else if (loan.collateral < rf.collateral) {
            IERC20(loan.collateralToken).safeTransferFrom(msg.sender,address(this),rf.collateral-loan.collateral);
        }
        loan.collateral = rf.collateral;

        loan.auctionLength = newPool.auctionLength;
        loan.interestRate = newPool.interestRate;
        loan.loanStartTimeStamp = block.timestamp;
        loan.lender = newPool.lender;

        emit OFPL__LaonIsUpdated(rf.loanId,block.timestamp);

    }




// 7569339885
    

    /////////////////// GETTER FUNCTIONS ////////////////

    function getPoolID(
        address _lender,
        address _loanToken,
        address _collateralToken
    ) public pure returns (bytes32 poolId) {
        poolId = keccak256(abi.encode(_lender, _loanToken, _collateralToken));
    }


    function getPoolInfo(bytes32 poolId) public view returns (Pool memory ){
        return pools[poolId];
    }

    function getLoanInfo(uint256 loanId) public view returns (Loan memory) {
        require(loanId < loans.length,"invalid loan id");
        return loans[loanId];
    }

    ////////////////// HELPER FUNCTIONS /////////////////

    function _updatePoolBalance(
        bytes32 poolId,
        uint256 _newPoolBalance
    ) internal {
        pools[poolId].poolBalance = _newPoolBalance;
        emit OFPL__PoolBalanceUpdated(poolId, _newPoolBalance, block.timestamp);
    }

    function _getLoanRation(
        address loanToken,
        address collateralToken,
        uint256 debt,
        uint256 collateral
    ) internal view returns (uint256) {
        uint8 debtDecimals = IERC20Metadata(loanToken).decimals();
        uint8 collateralDecimals = IERC20Metadata(collateralToken).decimals();
        uint256 normalizedDebt = debt * 10 ** (18 - debtDecimals);
        uint256 normalizedCollateral = collateral *
            10 ** (18 - collateralDecimals);
        uint256 loanRatio = (normalizedDebt / normalizedCollateral) * 1e18;
        return loanRatio;
    }


    function _calculateInterest(Loan memory loan)
    public
    view
    returns (uint256 lenderInterest, uint256 protocolFee)
    {
        uint256 timeElapsed = block.timestamp - loan.loanStartTimeStamp;

        uint256 interest =
            (loan.debt * loan.interestRate * timeElapsed)
            / (10000 * 365 days);

        protocolFee = (interest * s_lenderFee) / 10000;
        lenderInterest = interest - protocolFee;
    }


    function expectedTotalDebt(uint256 loanId)
    public
    view
    returns (uint256)
    {
        Loan memory loan = loans[loanId];
        require(loan.lender != address(0), "loan does not exist");

        uint256 elapsed = block.timestamp - loan.loanStartTimeStamp + 60;

        uint256 interest =
            (loan.debt * loan.interestRate * elapsed)
            / (10000 * 365 days);

        // protocol fee is taken from interest, not added on top
        return  interest;
    }


    //////////////////// MODIFIERS //////////////////

    modifier onlyLender(address lender) {
        require(msg.sender == lender, "unauthourzed");
        _;
    }
}
