pragma solidity ^0.5.16;

import "./AegisComptrollerInterface.sol";
import "./ATokenInterface.sol";
import "./BaseReporter.sol";
import "./Exponential.sol";
import "./AegisTokenCommon.sol";

/**
 * @title ERC-20 Token
 * @author Aegis
 */
contract AToken is ATokenInterface, BaseReporter, Exponential {
    modifier nonReentrant() {
        require(reentrant, "re-entered");
        reentrant = false;
        _;
        reentrant = true;
    }
    function getCashPrior() internal view returns (uint);
    function doTransferIn(address _from, uint _amount) internal returns (uint);
    function doTransferOut(address payable _to, uint _amount) internal;

    event DebugRepayLog(string message);

    /**
     * @notice init Aegis Comptroller ERC-20 Token
     * @param _name aToken name
     * @param _symbol aToken symbol
     * @param _decimals aToken decimals
     * @param _comptroller aToken aegisComptrollerInterface
     * @param _interestRateModel aToken interestRateModel
     * @param _initialExchangeRateMantissa aToken initExchangrRate
     */
    function initialize(string memory _name, string memory _symbol, uint8 _decimals,
            AegisComptrollerInterface _comptroller, InterestRateModel _interestRateModel, uint _initialExchangeRateMantissa) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        reentrant = true;

        require(msg.sender == admin, "Aegis AToken::initialize, no operation authority");
        require(borrowIndex==0 && accrualBlockNumber==0, "Aegis AToken::initialize, only init once");
        initialExchangeRateMantissa = _initialExchangeRateMantissa;
        require(initialExchangeRateMantissa > 0, "Aegis AToken::initialize, initial exchange rate must be greater than zero");
        uint _i = _setComptroller(_comptroller);
        require(_i == uint(Error.SUCCESS), "Aegis AToken::initialize, _setComptroller fail");
        accrualBlockNumber = block.number;
        borrowIndex = 1e18;
        _i = _setInterestRateModelFresh(_interestRateModel);
        require(_i == uint(Error.SUCCESS), "Aegis AToken::initialize, _setInterestRateModelFresh fail");
    }

    // Transfer `number` tokens from `msg.sender` to `dst`
    function transfer(address _dst, uint256 _number) external nonReentrant returns (bool) {
        return transferTokens(msg.sender, msg.sender, _dst, _number) == uint(Error.SUCCESS);
    }
    // Transfer `number` tokens from `src` to `dst`
    function transferFrom(address _src, address _dst, uint256 _number) external nonReentrant returns (bool) {
        return transferTokens(msg.sender, _src, _dst, _number) == uint(Error.SUCCESS);
    }

    /**
     * @notice authorize source account to transfer tokens
     * @param _spender Agent authorized transfer address
     * @param _src src address
     * @param _dst dst address
     * @param _tokens token number
     * @return SUCCESS
     */
    function transferTokens(address _spender, address _src, address _dst, uint _tokens) internal returns (uint) {
        if(_src == _dst){
            return fail(Error.ERROR, ErrorRemarks.ALLOW_SELF_TRANSFERS, 0);
        }
        uint _i = comptroller.transferAllowed(address(this), _src, _dst, _tokens);
        if(_i != 0){
            return fail(Error.ERROR, ErrorRemarks.COMPTROLLER_TRANSFER_ALLOWED, _i);
        }

        uint allowance = 0;
        if(_spender == _src) {
            allowance = uint(-1);
        }else {
            allowance = transferAllowances[_src][_spender];
        }

        MathError mathError;
        uint allowanceNew;
        uint srcTokensNew;
        uint dstTokensNew;
        (mathError, allowanceNew) = subUInt(allowance, _tokens);
        if (mathError != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.TRANSFER_NOT_ALLOWED, uint(Error.ERROR));
        }

        (mathError, srcTokensNew) = subUInt(accountTokens[_src], _tokens);
        if (mathError != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.TRANSFER_NOT_ENOUGH, uint(Error.ERROR));
        }

        (mathError, dstTokensNew) = addUInt(accountTokens[_dst], _tokens);
        if (mathError != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.TRANSFER_TOO_MUCH, uint(Error.ERROR));
        }
        
        accountTokens[_src] = srcTokensNew;
        accountTokens[_dst] = dstTokensNew;

        if (allowance != uint(-1)) {
            transferAllowances[_src][_spender] = allowanceNew;
        }
        
        emit Transfer(_src, _dst, _tokens);
        comptroller.transferVerify(address(this), _src, _dst, _tokens);
        return uint(Error.SUCCESS);
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @param _spender address spender
     * @param _amount approve amount
     * @return bool
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        address src = msg.sender;
        transferAllowances[src][_spender] = _amount;
        emit Approval(src, _spender, _amount);
        return true;
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param _owner address owner
     * @param _spender address spender
     * @return SUCCESS
     */
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return transferAllowances[_owner][_spender];
    }

    /**
     * @notice Get the token balance of the `owner`
     * @param _owner address owner
     * @return SUCCESS
     */
    function balanceOf(address _owner) external view returns (uint256) {
        return accountTokens[_owner];
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @param _owner address owner
     * @return balance
     */
    function balanceOfUnderlying(address _owner) external returns (uint) {
        Exp memory exchangeRate = Exp({mantissa: exchangeRateCurrent()});
        (MathError mErr, uint balance) = mulScalarTruncate(exchangeRate, accountTokens[_owner]);
        require(mErr == MathError.NO_ERROR, "balanceOfUnderlying fail");
        return balance;
    }

    /**
     * @notice Current exchangeRate from the underlying to the AToken
     * @return uint exchangeRate
     */
    function exchangeRateCurrent() public nonReentrant returns (uint) {
        require(accrueInterest() == uint(Error.SUCCESS), "exchangeRateCurrent::accrueInterest fail");
        return exchangeRateStored();
    }

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @param _mintAmount mint number
     * @return SUCCESS, number
     */
    function mintInternal(uint _mintAmount) internal nonReentrant returns (uint, uint) {
        uint error = accrueInterest();
        if (error != uint(Error.SUCCESS)) {
            return (fail(Error(error), ErrorRemarks.MINT_ACCRUE_INTEREST_FAILED, 0), 0);
        }
        return mintFresh(msg.sender, _mintAmount);
    }

    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @return SUCCESS
     */
    function accrueInterest() public returns (uint) {
        uint currentBlockNumber = block.number;
        uint accrualBlockNumberPrior = accrualBlockNumber;
        if(currentBlockNumber == accrualBlockNumberPrior){
            return uint(Error.SUCCESS);
        }

        // pull memory
        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        require(borrowRateMantissa <= borrowRateMaxMantissa, "accrueInterest::interestRateModel.getBorrowRate, borrow rate high");

        (MathError mathErr, uint blockDelta) = subUInt(currentBlockNumber, accrualBlockNumberPrior);
        require(mathErr == MathError.NO_ERROR, "accrueInterest::subUInt, block delta fail");

        Exp memory simpleInterestFactor;
        uint interestAccumulated;
        uint totalBorrowsNew;
        uint totalReservesNew;
        uint borrowIndexNew;

        (mathErr, simpleInterestFactor) = mulScalar(Exp({mantissa: borrowRateMantissa}), blockDelta);
        if (mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.ACCRUE_INTEREST_SIMPLE_INTEREST_FACTOR_CALCULATION_FAILED, uint(mathErr));
        }

        (mathErr, interestAccumulated) = mulScalarTruncate(simpleInterestFactor, borrowsPrior);
        if (mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.ACCRUE_INTEREST_ACCUMULATED_INTEREST_CALCULATION_FAILED, uint(mathErr));
        }

        (mathErr, totalBorrowsNew) = addUInt(interestAccumulated, borrowsPrior);
        if (mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.ACCRUE_INTEREST_NEW_TOTAL_BORROWS_CALCULATION_FAILED, uint(mathErr));
        }

        (mathErr, totalReservesNew) = mulScalarTruncateAddUInt(Exp({mantissa: reserveFactorMantissa}), interestAccumulated, reservesPrior);
        if (mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.ACCRUE_INTEREST_NEW_TOTAL_RESERVES_CALCULATION_FAILED, uint(mathErr));
        }

        (mathErr, borrowIndexNew) = mulScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);
        if (mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.ACCRUE_INTEREST_NEW_BORROW_INDEX_CALCULATION_FAILED, uint(mathErr));
        }

        // push storage
        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;

        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
        return uint(Error.SUCCESS);
    }

    /**
     * @notice User supplies assets into the market and receives cTokens in exchange
     * @dev mintTokens = actualMintAmount / exchangeRate
     * @dev totalSupplyNew = totalSupply + mintTokens
     * @dev accountTokensNew = accountTokens[_minter] + mintTokens
     * @param _minter address minter
     * @param _mintAmount mint amount
     * @return SUCCESS, number
     */
    function mintFresh(address _minter, uint _mintAmount)internal returns (uint, uint) {
        if(block.number != accrualBlockNumber) {
            return (fail(Error.ERROR, ErrorRemarks.MINT_FRESHNESS_CHECK, uint(Error.ERROR)), 0);
        }
        uint allowed = comptroller.mintAllowed(address(this), _minter, _mintAmount);
        if(allowed != 0){
            return (fail(Error.ERROR, ErrorRemarks.MINT_COMPTROLLER_REJECTION, allowed), 0);
        }

        MintLocalVars memory vars;
        (vars.mathErr, vars.exchangeRateMantissa) = exchangeRateStoredInternal();
        if(vars.mathErr != MathError.NO_ERROR) {
            return (fail(Error.ERROR, ErrorRemarks.MINT_EXCHANGE_RATE_READ_FAILED, uint(vars.mathErr)), 0);
        }

        vars.actualMintAmount = doTransferIn(_minter, _mintAmount);

        (vars.mathErr, vars.mintTokens) = divScalarByExpTruncate(vars.actualMintAmount, Exp({mantissa: vars.exchangeRateMantissa}));
        require(vars.mathErr == MathError.NO_ERROR, "mintFresh::divScalarByExpTruncate fail");

        (vars.mathErr, vars.totalSupplyNew) = addUInt(totalSupply, vars.mintTokens);
        require(vars.mathErr == MathError.NO_ERROR, "mintFresh::addUInt totalSupply fail");

        (vars.mathErr, vars.accountTokensNew) = addUInt(accountTokens[_minter], vars.mintTokens);
        require(vars.mathErr == MathError.NO_ERROR, "mintFresh::addUInt accountTokens fail");

        totalSupply = vars.totalSupplyNew;
        accountTokens[_minter] = vars.accountTokensNew;

        emit Mint(_minter, vars.actualMintAmount, vars.mintTokens);
        emit Transfer(address(this), _minter, vars.mintTokens);

        comptroller.mintVerify(address(this), _minter, vars.actualMintAmount, vars.mintTokens);
        return (uint(Error.SUCCESS), vars.actualMintAmount);
    }

    /**
     * @notice Current exchangeRate from the underlying to the AToken
     * @return uint exchangeRate
     */
    function exchangeRateStored() public view returns (uint) {
        (MathError err, uint rate) = exchangeRateStoredInternal();
        require(err == MathError.NO_ERROR, "exchangeRateStored::exchangeRateStoredInternal fail");
        return rate;
    }

    /**
     * @notice Current exchangeRate from the underlying to the AToken
     * @dev exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
     * @return SUCCESS, exchangeRate
     */
    function exchangeRateStoredInternal() internal view returns (MathError, uint) {
        if(totalSupply == 0){
            return (MathError.NO_ERROR, initialExchangeRateMantissa);
        }

        uint _totalSupply = totalSupply;
        uint totalCash = getCashPrior();
        uint cashPlusBorrowsMinusReserves;
        
        MathError err;
        (err, cashPlusBorrowsMinusReserves) = addThenSubUInt(totalCash, totalBorrows, totalReserves);
        if(err != MathError.NO_ERROR) {
            return (err, 0);
        }
        
        Exp memory exchangeRate;
        (err, exchangeRate) = getExp(cashPlusBorrowsMinusReserves, _totalSupply);
        if(err != MathError.NO_ERROR) {
            return (err, 0);
        }
        return (MathError.NO_ERROR, exchangeRate.mantissa);
    }

    function getCash() external view returns (uint) {
        return getCashPrior();
    }

    /**
     * @notice Get a snapshot of the account's balances and the cached exchange rate
     * @param _address address
     * @return SUCCESS, balance, balance, exchangeRate
     */
    function getAccountSnapshot(address _address) external view returns (uint, uint, uint, uint) {
        MathError err;
        uint borrowBalance;
        uint exchangeRateMantissa;

        (err, borrowBalance) = borrowBalanceStoredInternal(_address);
        if(err != MathError.NO_ERROR){
            return (uint(Error.ERROR), 0, 0, 0);
        }
        (err, exchangeRateMantissa) = exchangeRateStoredInternal();
        if(err != MathError.NO_ERROR){
            return (uint(Error.ERROR), 0, 0, 0);
        }
        return (uint(Error.SUCCESS), accountTokens[_address], borrowBalance, exchangeRateMantissa);
    }

    /**
     * @notice current per-block borrow interest rate for this aToken
     * @return current borrowRate
     */
    function borrowRatePerBlock() external view returns (uint) {
        return interestRateModel.getBorrowRate(getCashPrior(), totalBorrows, totalReserves);
    }

    /**
     * @notice current per-block supply interest rate for this aToken
     * @return current supplyRate
     */
    function supplyRatePerBlock() external view returns (uint) {
        return interestRateModel.getSupplyRate(getCashPrior(), totalBorrows, totalReserves, reserveFactorMantissa);
    }

    /**
     * @notice current total borrows plus accrued interest
     * @return totalBorrows
     */
    function totalBorrowsCurrent() external nonReentrant returns (uint) {
        require(accrueInterest() == uint(Error.SUCCESS), "totalBorrowsCurrent::accrueInterest fail");
        return totalBorrows;
    }

    /**
     * @notice current borrow limit by account
     * @param _account address
     * @return borrowBalance
     */
    function borrowBalanceCurrent(address _account) external nonReentrant returns (uint) {
        require(accrueInterest() == uint(Error.SUCCESS), "borrowBalanceCurrent::accrueInterest fail");
        return borrowBalanceStored(_account);
    }

    /**
     * @notice Return the borrow balance of account based on stored data
     * @param _account address
     * @return borrowBalance
     */
    function borrowBalanceStored(address _account) public view returns (uint) {
        (MathError err, uint result) = borrowBalanceStoredInternal(_account);
        require(err == MathError.NO_ERROR, "borrowBalanceStored::borrowBalanceStoredInternal fail");
        return result;
    }

    /**
     * @notice Return borrow balance of account based on stored data
     * @param _account address
     * @return SUCCESS, number
     */
    function borrowBalanceStoredInternal(address _account) internal view returns (MathError, uint) {
        BorrowBalanceInfomation storage borrowBalanceInfomation = accountBorrows[_account];
        if(borrowBalanceInfomation.principal == 0) {
            return (MathError.NO_ERROR, 0);
        }
        
        MathError err;
        uint principalTimesIndex;
        (err, principalTimesIndex) = mulUInt(borrowBalanceInfomation.principal, borrowIndex);
        if(err != MathError.NO_ERROR){
            return (err, 0);
        }
        
        uint balance;
        (err, balance) = divUInt(principalTimesIndex, borrowBalanceInfomation.interestIndex);
        if(err != MathError.NO_ERROR){
            return (err, 0);
        }
        return (MathError.NO_ERROR, balance);
    }

    /**
     * @notice Sender redeems aTokens in exchange for the underlying asset
     * @param _redeemTokens aToken number
     * @return SUCCESS
     */
    function redeemInternal(uint _redeemTokens) internal nonReentrant returns (uint) {
        if(_redeemTokens == 0){
            return fail(Error.ERROR, ErrorRemarks.CANNOT_BE_ZERO, uint(Error.ERROR));
        }
        uint err = accrueInterest();
        if(err != uint(Error.SUCCESS)) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_ACCRUE_INTEREST_FAILED, err);
        }
        return redeemFresh(msg.sender, _redeemTokens, 0);
    }

    /**
     * @notice Sender redeems aTokens in exchange for a specified amount of underlying asset
     * @param _redeemAmount The amount of underlying to receive from redeeming aTokens
     * @return SUCCESS
     */
    function redeemUnderlyingInternal(uint _redeemAmount) internal nonReentrant returns (uint) {
        if(_redeemAmount == 0){
            return fail(Error.ERROR, ErrorRemarks.CANNOT_BE_ZERO, uint(Error.ERROR));
        }
        uint err = accrueInterest();
        if(err != uint(Error.SUCCESS)) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_ACCRUE_INTEREST_FAILED, err);
        }
        return redeemFresh(msg.sender, 0, _redeemAmount);
    }

    /**
     * @notice User redeems cTokens in exchange for the underlying asset
     * @dev redeemAmount = redeemTokensIn x exchangeRateCurrent
     * @dev redeemTokens = redeemAmountIn / exchangeRate
     * @dev totalSupplyNew = totalSupply - redeemTokens
     * @dev accountTokensNew = accountTokens[redeemer] - redeemTokens
     * @param _redeemer aToken address
     * @param _redeemTokensIn redeemTokensIn The number of aTokens to redeem into underlying
     * @param _redeemAmountIn redeemAmountIn The number of underlying tokens to receive from redeeming aTokens
     * @return SUCCESS
     */
    function redeemFresh(address payable _redeemer, uint _redeemTokensIn, uint _redeemAmountIn) internal returns (uint) {
        if (accrualBlockNumber != block.number) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_FRESHNESS_CHECK, uint(Error.ERROR));
        }

        RedeemLocalVars memory vars;
        (vars.mathErr, vars.exchangeRateMantissa) = exchangeRateStoredInternal();
        if(vars.mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_EXCHANGE_RATE_READ_FAILED, uint(vars.mathErr));
        }
        if(_redeemTokensIn > 0) {
            vars.redeemTokens = _redeemTokensIn;
            (vars.mathErr, vars.redeemAmount) = mulScalarTruncate(Exp({mantissa: vars.exchangeRateMantissa}), _redeemTokensIn);
            if (vars.mathErr != MathError.NO_ERROR) {
                return fail(Error.ERROR, ErrorRemarks.REDEEM_EXCHANGE_TOKENS_CALCULATION_FAILED, uint(vars.mathErr));
            }
        } else {
            (vars.mathErr, vars.redeemTokens) = divScalarByExpTruncate(_redeemAmountIn, Exp({mantissa: vars.exchangeRateMantissa}));
            if (vars.mathErr != MathError.NO_ERROR) {
                return fail(Error.ERROR, ErrorRemarks.REDEEM_EXCHANGE_AMOUNT_CALCULATION_FAILED, uint(vars.mathErr));
            }
            vars.redeemAmount = _redeemAmountIn;
        }
        uint allowed = comptroller.redeemAllowed(address(this), _redeemer, vars.redeemTokens);
        if (allowed != 0) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_COMPTROLLER_REJECTION, allowed);
        }
        (vars.mathErr, vars.totalSupplyNew) = subUInt(totalSupply, vars.redeemTokens);
        if (vars.mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_NEW_TOTAL_SUPPLY_CALCULATION_FAILED, uint(vars.mathErr));
        }

        (vars.mathErr, vars.accountTokensNew) = subUInt(accountTokens[_redeemer], vars.redeemTokens);
        if (vars.mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED, uint(vars.mathErr));
        }

        if (getCashPrior() < vars.redeemAmount) {
            return fail(Error.ERROR, ErrorRemarks.REDEEM_TRANSFER_OUT_NOT_POSSIBLE, uint(Error.ERROR));
        }

        doTransferOut(_redeemer, vars.redeemAmount);

        // push storage
        totalSupply = vars.totalSupplyNew;
        accountTokens[_redeemer] = vars.accountTokensNew;

        emit Transfer(_redeemer, address(this), vars.redeemTokens);
        emit Redeem(_redeemer, vars.redeemAmount, vars.redeemTokens);
        comptroller.redeemVerify(address(this), _redeemer, vars.redeemAmount, vars.redeemTokens);
        return uint(Error.SUCCESS);
    }

    /**
     * @notice Sender borrows assets from the protocol to their own address
     * @param _borrowAmount: The amount of the underlying asset to borrow
     * @return SUCCESS
     */
    function borrowInternal(uint _borrowAmount) internal nonReentrant returns (uint) {
        uint err = accrueInterest();
        if (err != uint(Error.SUCCESS)) {
            return fail(Error.ERROR, ErrorRemarks.BORROW_ACCRUE_INTEREST_FAILED, err);
        }
        return borrowFresh(msg.sender, _borrowAmount);
    }

    /**
     * @notice Sender borrows assets from the protocol to their own address
     * @param _borrower address
     * @param _borrowAmount number
     * @return SUCCESS
     */
    function borrowFresh(address payable _borrower, uint _borrowAmount) internal returns (uint) {
        uint allowed = comptroller.borrowAllowed(address(this), _borrower, _borrowAmount);
        if(allowed !=0) {
            return fail(Error.ERROR, ErrorRemarks.BORROW_COMPTROLLER_REJECTION, allowed);
        }
        if(block.number != accrualBlockNumber) {
            return fail(Error.ERROR, ErrorRemarks.BORROW_FRESHNESS_CHECK, uint(Error.ERROR));
        }
        if(_borrowAmount > getCashPrior()) {
            return fail(Error.ERROR, ErrorRemarks.BORROW_CASH_NOT_AVAILABLE, uint(Error.ERROR));
        }

        BorrowLocalVars memory vars;
        (vars.mathErr, vars.accountBorrows) = borrowBalanceStoredInternal(_borrower);
        if (vars.mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED, uint(vars.mathErr));
        }

        (vars.mathErr, vars.accountBorrowsNew) = addUInt(vars.accountBorrows, _borrowAmount);
        if (vars.mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED, uint(vars.mathErr));
        }

        (vars.mathErr, vars.totalBorrowsNew) = addUInt(totalBorrows, _borrowAmount);
        if (vars.mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED, uint(vars.mathErr));
        }

        doTransferOut(_borrower, _borrowAmount);

        // push storage
        accountBorrows[_borrower].principal = vars.accountBorrowsNew;
        accountBorrows[_borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        emit Borrow(_borrower, _borrowAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);
        comptroller.borrowVerify(address(this), _borrower, _borrowAmount);
        return uint(Error.SUCCESS);
    }

    /**
     * @notice Sender repays their own borrow
     * @param _repayAmount The amount to repay
     * @return SUCCESS, number
     */
    function repayBorrowInternal(uint _repayAmount) internal nonReentrant returns (uint, uint) {
        uint err = accrueInterest();
        if (err != uint(Error.SUCCESS)) {
            return (fail(Error.ERROR, ErrorRemarks.REPAY_BORROW_ACCRUE_INTEREST_FAILED, err), 0);
        }
        emit DebugRepayLog("repayBorrowInternal::accrueInterest success, next repayBorrowFresh");
        return repayBorrowFresh(msg.sender, msg.sender, _repayAmount);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param _borrower Borrower address
     * @param _repayAmount The amount to repay
     * @return SUCCESS, number
     */
    function repayBorrowBehalfInternal(address _borrower, uint _repayAmount) internal nonReentrant returns (uint, uint) {
        uint err = accrueInterest();
        if (err != uint(Error.SUCCESS)) {
            return (fail(Error.ERROR, ErrorRemarks.REPAY_BEHALF_ACCRUE_INTEREST_FAILED, err), 0);
        }
        return repayBorrowFresh(msg.sender, _borrower, _repayAmount);
    }

    /**
     * @notice Repay Borrow
     * @param _payer The account paying off the borrow
     * @param _borrower The account with the debt being payed off
     * @param _repayAmount The amount of undelrying tokens being returned
     * @return SUCCESS, number
     */
    function repayBorrowFresh(address _payer, address _borrower, uint _repayAmount) internal returns (uint, uint) {
        if(block.number != accrualBlockNumber) {
            return (fail(Error.ERROR, ErrorRemarks.REPAY_BORROW_FRESHNESS_CHECK, uint(Error.ERROR)), 0);
        }
        emit DebugRepayLog("repayBorrowFresh::block.number != accrualBlockNumber success, next comptroller.repayBorrowAllowed");
        uint allowed = comptroller.repayBorrowAllowed(address(this), _payer, _borrower, _repayAmount);
        if (allowed != 0) {
            return (fail(Error.ERROR, ErrorRemarks.REPAY_BORROW_COMPTROLLER_REJECTION, allowed), 0);
        }
        emit DebugRepayLog("repayBorrowFresh::comptroller.repayBorrowAllowed success, next comptroller.repayBorrowAllowed");
        RepayBorrowLocalVars memory vars;
        vars.borrowerIndex = accountBorrows[_borrower].interestIndex;
        (vars.mathErr, vars.accountBorrows) = borrowBalanceStoredInternal(_borrower);
        if (vars.mathErr != MathError.NO_ERROR) {
            return (fail(Error.ERROR, ErrorRemarks.REPAY_BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED, uint(vars.mathErr)), 0);
        }
        emit DebugRepayLog("repayBorrowFresh::borrowBalanceStoredInternal success, next doTransferIn");
        if (_repayAmount == uint(-1)) {
            vars.repayAmount = vars.accountBorrows;
        } else {
            vars.repayAmount = _repayAmount;
        }
        vars.actualRepayAmount = doTransferIn(_payer, vars.repayAmount);
        (vars.mathErr, vars.accountBorrowsNew) = subUInt(vars.accountBorrows, vars.actualRepayAmount);
        emit DebugRepayLog("repayBorrowFresh::subUInt(vars.accountBorrows, vars.actualRepayAmount) success, next doTransferIn");
        require(vars.mathErr == MathError.NO_ERROR, "repayBorrowFresh::subUInt vars.accountBorrows fail");

        (vars.mathErr, vars.totalBorrowsNew) = subUInt(totalBorrows, vars.actualRepayAmount);
        emit DebugRepayLog("repayBorrowFresh::subUInt(totalBorrows, vars.actualRepayAmount) success, next doTransferIn");
        require(vars.mathErr == MathError.NO_ERROR, "repayBorrowFresh::subUInt totalBorrows fail");

        // push storage
        accountBorrows[_borrower].principal = vars.accountBorrowsNew;
        accountBorrows[_borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        emit RepayBorrow(_payer, _borrower, vars.actualRepayAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);
        comptroller.repayBorrowVerify(address(this), _payer, _borrower, vars.actualRepayAmount, vars.borrowerIndex);
        return (uint(Error.SUCCESS), vars.actualRepayAmount);
    }

    /**
     * @notice The liquidator liquidates the borrowers collateral, The collateral seized is transferred to the liquidator
     * @param _borrower address borrower
     * @param _repayAmount amount
     * @param _aTokenInterface aToken
     * @return SUCCESS, number
     */
    function liquidateBorrowInternal(address _borrower, uint _repayAmount, ATokenInterface _aTokenInterface) internal nonReentrant returns (uint, uint) {
        if (_borrower == msg.sender) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_LIQUIDATOR_IS_BORROWER, uint(Error.ERROR)), 0);
        }
        if (_repayAmount == 0) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_CLOSE_AMOUNT_IS_ZERO, uint(Error.ERROR)), 0);
        }
        if (_repayAmount == uint(-1)) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_CLOSE_AMOUNT_IS_UINT_MAX, uint(Error.ERROR)), 0);
        }
        uint err = accrueInterest();
        if (err != uint(Error.SUCCESS)) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_ACCRUE_BORROW_INTEREST_FAILED, err), 0);
        }
        err = _aTokenInterface.accrueInterest();
        if (err != uint(Error.SUCCESS)) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_ACCRUE_COLLATERAL_INTEREST_FAILED, err), 0);
        }
        return liquidateBorrowFresh(msg.sender, _borrower, _repayAmount, _aTokenInterface);
    }

    /**
     * @notice The liquidator liquidates the borrowers collateral, The collateral seized is transferred to the liquidator.
     * @param _liquidator The address repaying the borrow and seizing collateral
     * @param _borrower The borrower of this cToken to be liquidated
     * @param _repayAmount The amount of the underlying borrowed asset to repay
     * @param _aTokenInterface The market in which to seize collateral from the borrower
     * @return SUCCESS, number
     */
    function liquidateBorrowFresh(address _liquidator, address _borrower, uint _repayAmount, ATokenInterface _aTokenInterface) internal returns (uint, uint) {
        uint allowed = comptroller.liquidateBorrowAllowed(address(this), address(_aTokenInterface), _liquidator, _borrower, _repayAmount);
        if (allowed != 0) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_COMPTROLLER_REJECTION, allowed), 0);
        }
        if(block.number != accrualBlockNumber) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_FRESHNESS_CHECK, uint(Error.ERROR)), 0);
        }
        if(block.number != _aTokenInterface.accrualBlockNumber()){
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_COLLATERAL_FRESHNESS_CHECK, uint(Error.ERROR)), 0);
        }

        (uint repayBorrowError, uint actualRepayAmount) = repayBorrowFresh(_liquidator, _borrower, _repayAmount);
        if (repayBorrowError != uint(Error.SUCCESS)) {
            return (fail(Error.ERROR, ErrorRemarks.LIQUIDATE_REPAY_BORROW_FRESH_FAILED, repayBorrowError), 0);
        }

        (uint amountSeizeError, uint seizeTokens) = comptroller.liquidateCalculateSeizeTokens(address(this), address(_aTokenInterface), actualRepayAmount);
        require(amountSeizeError == uint(Error.SUCCESS), "liquidateBorrowFresh::comptroller.liquidateCalculateSeizeTokens fail");
        require(_aTokenInterface.balanceOf(_borrower) >= seizeTokens, "liquidateBorrowFresh::_aTokenInterface.balanceOf fail");

        uint seizeError;
        if (address(_aTokenInterface) == address(this)) {
            seizeError = seizeInternal(address(this), _liquidator, _borrower, seizeTokens);
        } else {
            seizeError = _aTokenInterface.seize(_liquidator, _borrower, seizeTokens);
        }
        require(seizeError == uint(Error.SUCCESS), "liquidateBorrowFresh::seizeError fail");
        
        emit LiquidateBorrow(_liquidator, _borrower, actualRepayAmount, address(_aTokenInterface), seizeTokens);
        comptroller.liquidateBorrowVerify(address(this), address(_aTokenInterface), _liquidator, _borrower, actualRepayAmount, seizeTokens);
        return (uint(Error.SUCCESS), actualRepayAmount);
    }

    /**
     * @notice Transfers collateral tokens to the liquidator
     * @param _liquidator address
     * @param _borrower address
     * @param _seizeTokens seize number
     * @return SUCCESS
     */
    function seize(address _liquidator, address _borrower, uint _seizeTokens) external nonReentrant returns (uint) {
        if(_liquidator == _borrower) {
            return fail(Error.ERROR, ErrorRemarks.LIQUIDATE_SEIZE_LIQUIDATOR_IS_BORROWER, uint(Error.ERROR));
        }
        return seizeInternal(msg.sender, _liquidator, _borrower, _seizeTokens);
    }

    /**
     * @notice Transfers collateral tokens to the liquidator. Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another AToken
     * @dev borrowerTokensNew = accountTokens[borrower] - seizeTokens
     * @dev liquidatorTokensNew = accountTokens[liquidator] + seizeTokens
     * @param _token address
     * @param _liquidator address
     * @param _borrower address
     * @param _seizeTokens seize number
     * @return SUCCESS
     */
    function seizeInternal(address _token, address _liquidator, address _borrower, uint _seizeTokens) internal returns (uint) {
        uint allowed = comptroller.seizeAllowed(address(this), _token, _liquidator, _borrower, _seizeTokens);
        if (allowed != 0) {
            return fail(Error.ERROR, ErrorRemarks.LIQUIDATE_SEIZE_COMPTROLLER_REJECTION, allowed);
        }
        
        MathError mathErr;
        uint borrowerTokensNew;
        uint liquidatorTokensNew;
        (mathErr, borrowerTokensNew) = subUInt(accountTokens[_borrower], _seizeTokens);
        if (mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.LIQUIDATE_SEIZE_BALANCE_DECREMENT_FAILED, uint(mathErr));
        }
        (mathErr, liquidatorTokensNew) = addUInt(accountTokens[_liquidator], _seizeTokens);
        if (mathErr != MathError.NO_ERROR) {
            return fail(Error.ERROR, ErrorRemarks.LIQUIDATE_SEIZE_BALANCE_INCREMENT_FAILED, uint(mathErr));
        }

        // push storage
        accountTokens[_borrower] = borrowerTokensNew;
        accountTokens[_liquidator] = liquidatorTokensNew;

        emit Transfer(_borrower, _liquidator, _seizeTokens);
        comptroller.seizeVerify(address(this), _token, _liquidator, _borrower, _seizeTokens);
        return uint(Error.SUCCESS);
    }

    struct MintLocalVars {
        Error err;
        MathError mathErr;
        uint exchangeRateMantissa;
        uint mintTokens;
        uint totalSupplyNew;
        uint accountTokensNew;
        uint actualMintAmount;
    }

    struct RedeemLocalVars {
        Error err;
        MathError mathErr;
        uint exchangeRateMantissa;
        uint redeemTokens;
        uint redeemAmount;
        uint totalSupplyNew;
        uint accountTokensNew;
    }

    struct BorrowLocalVars {
        MathError mathErr;
        uint accountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;
    }

    struct RepayBorrowLocalVars {
        Error err;
        MathError mathErr;
        uint repayAmount;
        uint borrowerIndex;
        uint accountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;
        uint actualRepayAmount;
    }

    function _setPendingAdmin(address payable _newAdmin) external returns (uint) {
        if(admin != msg.sender) {
            return fail(Error.ERROR, ErrorRemarks.SET_PENDING_ADMIN_OWNER_CHECK, uint(Error.ERROR));
        }
        address _old = pendingAdmin;
        pendingAdmin = _newAdmin;
        emit NewPendingAdmin(_old, _newAdmin);
        return uint(Error.SUCCESS);
    }

    function _acceptAdmin() external returns (uint) {
        if (msg.sender != pendingAdmin || msg.sender == address(0)) {
            return fail(Error.ERROR, ErrorRemarks.ACCEPT_ADMIN_PENDING_ADMIN_CHECK, uint(Error.ERROR));
        }
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;
        admin = pendingAdmin;
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
        return uint(Error.SUCCESS);
    }

    function _setComptroller(AegisComptrollerInterface _aegisComptrollerInterface) public returns (uint) {
        if(admin != msg.sender) {
            return fail(Error.ERROR, ErrorRemarks.SET_COMPTROLLER_OWNER_CHECK, uint(Error.ERROR));
        }
        AegisComptrollerInterface old = comptroller;
        require(_aegisComptrollerInterface.aegisComptroller(), "AToken::_setComptroller _aegisComptrollerInterface false");
        comptroller = _aegisComptrollerInterface;

        emit NewComptroller(old, _aegisComptrollerInterface);
        return uint(Error.SUCCESS);
    }

    function _setReserveFactor(uint _newReserveFactor) external nonReentrant returns (uint) {
        uint err = accrueInterest();
        if (err != uint(Error.SUCCESS)) {
            return fail(Error.ERROR, ErrorRemarks.SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED, err);
        }
        return _setReserveFactorFresh(_newReserveFactor);
    }

    function _setReserveFactorFresh(uint _newReserveFactor) internal returns (uint) {
        if(block.number != accrualBlockNumber) {
            return fail(Error.ERROR, ErrorRemarks.SET_RESERVE_FACTOR_FRESH_CHECK, uint(Error.ERROR));
        }
        if(msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_RESERVE_FACTOR_ADMIN_CHECK, uint(Error.ERROR));
        }
        if(_newReserveFactor > reserveFactorMaxMantissa) {
            return fail(Error.ERROR, ErrorRemarks.SET_RESERVE_FACTOR_BOUNDS_CHECK, uint(Error.ERROR));
        }
        uint old = reserveFactorMantissa;
        reserveFactorMantissa = _newReserveFactor;

        emit NewReserveFactor(old, _newReserveFactor);
        return uint(Error.SUCCESS);
    }

    function _addResevesInternal(uint _addAmount) internal nonReentrant returns (uint) {
        uint error = accrueInterest();
        if (error != uint(Error.SUCCESS)) {
            return fail(Error.ERROR, ErrorRemarks.ADD_RESERVES_ACCRUE_INTEREST_FAILED, uint(Error.ERROR));
        }
        uint item;
        (error, item) = _addReservesFresh(_addAmount);
        return error;
    }

    function _addReservesFresh(uint _addAmount) internal returns (uint, uint) {
        if(block.number != accrualBlockNumber) {
            return (fail(Error.ERROR, ErrorRemarks.ADD_RESERVES_FRESH_CHECK, uint(Error.ERROR)), 0);
        }
        
        uint actualAddAmount = doTransferIn(msg.sender, _addAmount);
        uint totalReservesNew = totalReserves + actualAddAmount;

        require(totalReservesNew >= totalReserves, "_addReservesFresh::totalReservesNew >= totalReserves fail");

        // push storage
        totalReserves = totalReservesNew;

        emit ReservesAdded(msg.sender, actualAddAmount, totalReservesNew);
        return (uint(Error.SUCCESS), actualAddAmount);
    }

    function _reduceReserves(uint _reduceAmount) external nonReentrant returns (uint) {
        uint error = accrueInterest();
        if (error != uint(Error.SUCCESS)) {
            return fail(Error.ERROR, ErrorRemarks.REDUCE_RESERVES_ACCRUE_INTEREST_FAILED, uint(Error.ERROR));
        }
        return _reduceReservesFresh(_reduceAmount);
    }

    function _reduceReservesFresh(uint _reduceAmount) internal returns (uint) {
        if(admin != msg.sender) {
            return fail(Error.ERROR, ErrorRemarks.REDUCE_RESERVES_ADMIN_CHECK, uint(Error.ERROR));
        }
        if(block.number != accrualBlockNumber) {
            return fail(Error.ERROR, ErrorRemarks.REDUCE_RESERVES_FRESH_CHECK, uint(Error.ERROR));
        }
        if(_reduceAmount > getCashPrior()) {
            return fail(Error.ERROR, ErrorRemarks.REDUCE_RESERVES_CASH_NOT_AVAILABLE, uint(Error.ERROR));
        }
        if(_reduceAmount > totalReserves) {
            return fail(Error.ERROR, ErrorRemarks.REDUCE_RESERVES_VALIDATION, uint(Error.ERROR));
        }

        uint totalReservesNew = totalReserves - _reduceAmount;
        require(totalReservesNew <= totalReserves, "_reduceReservesFresh::totalReservesNew <= totalReserves fail");

        // push storage
        totalReserves = totalReservesNew;
        doTransferOut(admin, _reduceAmount);
        emit ReservesReduced(admin, _reduceAmount, totalReservesNew);
        return uint(Error.SUCCESS);
    }

    function _setInterestRateModel(InterestRateModel _interestRateModel) public returns (uint) {
        uint err = accrueInterest();
        if (err != uint(Error.SUCCESS)) {
            return fail(Error.ERROR, ErrorRemarks.SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED, uint(Error.ERROR));
        }
        return _setInterestRateModelFresh(_interestRateModel);
    }

    function _setInterestRateModelFresh(InterestRateModel _interestRateModel) internal returns (uint) {
        if(msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_INTEREST_RATE_MODEL_OWNER_CHECK, uint(Error.ERROR));
        }
        if(block.number != accrualBlockNumber) {
            return fail(Error.ERROR, ErrorRemarks.SET_INTEREST_RATE_MODEL_FRESH_CHECK, uint(Error.ERROR));
        }

        InterestRateModel old = interestRateModel;
        require(_interestRateModel.isInterestRateModel(), "_setInterestRateModelFresh::_interestRateModel.isInterestRateModel fail");
        interestRateModel = _interestRateModel;
        emit NewMarketInterestRateModel(old, _interestRateModel);
        return uint(Error.SUCCESS);
    }
}