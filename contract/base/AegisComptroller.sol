pragma solidity ^0.5.16;

import "./AegisComptrollerCommon.sol";
import "./AegisComptrollerInterface.sol";
import "./Exponential.sol";
import "./Unitroller.sol";
import "./BaseReporter.sol";

/**
 * @notice Aegis Comptroller contract
 * @author Aegis
 */
contract AegisComptroller is AegisComptrollerCommon, AegisComptrollerInterface, Exponential, BaseReporter {
    uint internal constant closeFactorMinMantissa = 0.05e18;
    uint internal constant closeFactorMaxMantissa = 0.9e18;
    uint internal constant collateralFactorMaxMantissa = 0.9e18;
    uint internal constant liquidationIncentiveMinMantissa = 1.0e18;
    uint internal constant liquidationIncentiveMaxMantissa = 1.5e18;

    constructor () public {
        admin = msg.sender;
    }

    /**
     * @notice Returns the assets an account has entered
     * @param _account address account
     * @return AToken[]
     */
    function getAssetsIn(address _account) external view returns (AToken[] memory) {
        return accountAssets[_account];
    }

    /**
     * @notice Whether the current account has corresponding assets
     * @param _account address account
     * @param _aToken AToken
     * @return bool
     */
    function checkMembership(address _account, AToken _aToken) external view returns (bool) {
        return markets[address(_aToken)].accountMembership[_account];
    }

    /**
     * @notice Enter Markets
     * @param _aTokens AToken[]
     * @return uint[]
     */
    function enterMarkets(address[] memory _aTokens) public returns (uint[] memory) {
        uint len = _aTokens.length;
        uint[] memory results = new uint[](len);
        for (uint i = 0; i < len; i++) {
            AToken aToken = AToken(_aTokens[i]);
            results[i] = uint(addToMarketInternal(aToken, msg.sender));
        }
        return results;
    }

    /**
     * @notice Add the market to the borrower's "assets in" for liquidity calculations
     * @param _aToken AToken address
     * @param _sender address sender
     * @return Error SUCCESS
     */
    function addToMarketInternal(AToken _aToken, address _sender) internal returns (Error) {
        Market storage marketToJoin = markets[address(_aToken)];
        if (!marketToJoin.isListed) {
            return Error.ERROR;
        }
        if (marketToJoin.accountMembership[_sender] == true) {
            return Error.SUCCESS;
        }
        if (accountAssets[_sender].length >= maxAssets)  {
            return Error.ERROR;
        }
        marketToJoin.accountMembership[_sender] = true;
        accountAssets[_sender].push(_aToken);

        emit MarketEntered(_aToken, _sender);
        return Error.SUCCESS;
    }

    /**
     * @notice Removes asset from sender's account liquidity calculation
     * @param _aTokenAddress aToken address
     * @return SUCCESS
     */
    function exitMarket(address _aTokenAddress) external returns (uint) {
        AToken aToken = AToken(_aTokenAddress);
        (uint err, uint tokensHeld, uint borrowBalance, uint exchangeRateMantissa) = aToken.getAccountSnapshot(msg.sender);
        require(err == uint(Error.SUCCESS), "AegisComptroller::exitMarket aToken.getAccountSnapshot fail");

        if (borrowBalance != 0) {
            return fail(Error.ERROR, ErrorRemarks.EXIT_MARKET_BALANCE_OWED, uint(Error.ERROR));
        }
        uint allowed = redeemAllowedInternal(_aTokenAddress, msg.sender, tokensHeld);
        if (allowed != 0) {
            return fail(Error.ERROR, ErrorRemarks.EXIT_MARKET_REJECTION, allowed);
        }

        Market storage marketToExit = markets[address(aToken)];
        if (!marketToExit.accountMembership[msg.sender]) {
            return uint(Error.SUCCESS);
        }
        delete marketToExit.accountMembership[msg.sender];

        AToken[] memory userAssetList = accountAssets[msg.sender];
        uint len = userAssetList.length;
        uint assetIndex = len;
        for (uint i = 0; i < len; i++) {
            if (userAssetList[i] == aToken) {
                assetIndex = i;
                break;
            }
        }
        assert(assetIndex < len);
        AToken[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.length--;

        emit MarketExited(aToken, msg.sender);
        return uint(Error.SUCCESS);
    }

    /**
     * @dev financial risk management
     */

    function mintAllowed(address _aToken, address _minter, uint _mintAmount) external returns (uint) {
        require(!_mintGuardianPaused, "AegisComptroller::mintAllowed _mintGuardianPaused fail");
        return uint(Error.SUCCESS);
    }
    function mintVerify(address _aToken, address _minter, uint _actualMintAmount, uint _mintTokens) external {
        if(true) {}
    }
    function borrowVerify(address _aToken, address _borrower, uint _borrowAmount) external {
        if(true) {}
    }
    function repayBorrowAllowed(address _aToken, address _payer, address _borrower, uint _repayAmount) external returns (uint) {
        require(!_borrowGuardianPaused, "AegisComptroller::repayBorrowAllowed _borrowGuardianPaused fail");
        return uint(Error.SUCCESS);
    }
    function repayBorrowVerify( address _aToken, address _payer, address _borrower, uint _actualRepayAmount, uint _borrowerIndex) external {
        if(true) {}
    }
    function liquidateBorrowAllowed(address _aTokenBorrowed, address _aTokenCollateral, address _liquidator, address _borrower, uint _repayAmount) external returns (uint) {
        return uint(Error.SUCCESS);
    }
    function liquidateBorrowVerify(address _aTokenBorrowed, address _aTokenCollateral, address _liquidator, address _borrower, uint _actualRepayAmount, uint _seizeTokens) external {
        if(true) {}
    }
    function seizeAllowed(address _aTokenCollateral, address _aTokenBorrowed, address _liquidator, address _borrower, uint _seizeTokens) external returns (uint) {
        require(!seizeGuardianPaused, "AegisComptroller::seizeAllowedseize seizeGuardianPaused fail");
        if (!markets[_aTokenCollateral].isListed || !markets[_aTokenBorrowed].isListed) {
            return uint(Error.ERROR);
        }
        if (AToken(_aTokenCollateral).comptroller() != AToken(_aTokenBorrowed).comptroller()) {
            return uint(Error.ERROR);
        }
        return uint(Error.SUCCESS);
    }
    function seizeVerify(address _aTokenCollateral, address _aTokenBorrowed, address _liquidator, address _borrower, uint _seizeTokens) external {
        if(true) {}
    }
    
    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market
     * @param _aToken aToken address
     * @param _redeemer address redeemer
     * @param _redeemTokens number
     * @return SUCCESS
     */
    function redeemAllowed(address _aToken, address _redeemer, uint _redeemTokens) external returns (uint) {
        uint allowed = redeemAllowedInternal(_aToken, _redeemer, _redeemTokens);
        if (allowed != uint(Error.SUCCESS)) {
            return allowed;
        }
        return uint(Error.SUCCESS);
    }

    function redeemAllowedInternal(address _aToken, address _redeemer, uint _redeemTokens) internal view returns (uint) {
        if (!markets[_aToken].isListed) {
            return uint(Error.ERROR);
        }
        if (!markets[_aToken].accountMembership[_redeemer]) {
            return uint(Error.SUCCESS);
        }
        (Error err, uint item, uint shortfall) = getHypotheticalAccountLiquidityInternal(_redeemer, AToken(_aToken), _redeemTokens, 0);
        if (err != Error.SUCCESS) {
            return uint(err);
        }
        if (shortfall > 0) {
            return uint(Error.ERROR);
        }
        return uint(Error.SUCCESS);
    }

    /**
     * @notice Validates redeem and reverts on rejection
     * @param _aToken address
     * @param _redeemer address
     * @param _redeemAmount number
     * @param _redeemTokens number
     */
    function redeemVerify(address _aToken, address _redeemer, uint _redeemAmount, uint _redeemTokens) external {
        if (_redeemTokens == 0 && _redeemAmount > 0) {
            revert("_redeemTokens zero");
        }
    }

    event DebugLogBorrowAllowed(uint i1, uint i2);
    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param _aToken AToken address
     * @param _borrower address borrower
     * @param _borrowAmount number
     * @return SUCCESS
     */
    function borrowAllowed(address _aToken, address _borrower, uint _borrowAmount) external returns (uint) {
        require(!borrowGuardianPaused[_aToken], "AegisComptroller::borrowAllowed borrowGuardianPaused fail");
        if (!markets[_aToken].isListed) {
            return uint(Error.ERROR);
        }
        if (!markets[_aToken].accountMembership[_borrower]) {
            require(msg.sender == _aToken, "AegisComptroller::accountMembership fail");
            Error err = addToMarketInternal(AToken(msg.sender), _borrower);
            if (err != Error.SUCCESS) {
                return uint(err);
            }
            assert(markets[_aToken].accountMembership[_borrower]);
        }
        if (oracle.getUnderlyingPrice(_aToken) == 0) {
            return uint(Error.ERROR);
        }
        (Error err, uint item, uint shortfall) = getHypotheticalAccountLiquidityInternal(_borrower, AToken(_aToken), 0, _borrowAmount);
        if (err != Error.SUCCESS) {
            return uint(err);
        }
        emit DebugLogBorrowAllowed(item, shortfall);
        if (item == 0 || shortfall > 0) {
            return uint(Error.ERROR);
        }
        return uint(Error.SUCCESS);
    }

    function transferAllowed(address _aToken, address _src, address _dst, uint _transferTokens) external returns (uint) {
        require(!transferGuardianPaused, "AegisComptroller::transferAllowed fail");
        uint allowed = redeemAllowedInternal(_aToken, _src, _transferTokens); 
        if (allowed != uint(Error.SUCCESS)) {
            return allowed;
        }
        return uint(Error.SUCCESS);
    }
    function transferVerify(address _aToken, address _src, address _dst, uint _transferTokens) external {
        if(true) {}
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @param _account address account
     * @return SUCCESS, number, number
     */
    function getAccountLiquidity(address _account) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(_account, AToken(0), 0, 0);
        return (uint(err), liquidity, shortfall);
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @param _account address account
     * @return SUCCESS, number, number
     */
    function getAccountLiquidityInternal(address _account) internal view returns (Error, uint, uint) {
        return getHypotheticalAccountLiquidityInternal(_account, AToken(0), 0, 0);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param _account address account
     * @param _aTokenModify address aToken
     * @param _redeemTokens number
     * @param _borrowAmount amount
     * @return ERROR, number, number
     */
    function getHypotheticalAccountLiquidity(address _account, address _aTokenModify, uint _redeemTokens, uint _borrowAmount) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(_account, AToken(_aTokenModify), _redeemTokens, _borrowAmount);
        return (uint(err), liquidity, shortfall);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @dev sumCollateral += tokensToDenom * cTokenBalance
     * @dev sumBorrowPlusEffects += oraclePrice * borrowBalance
     * @dev sumBorrowPlusEffects += tokensToDenom * redeemTokens
     * @dev sumBorrowPlusEffects += oraclePrice * borrowAmount
     * @param _account address account
     * @param _aTokenModify address aToken
     * @param _redeemTokens number
     * @param _borrowAmount amount
     * @return ERROR, number, number
     */
    function getHypotheticalAccountLiquidityInternal(address _account, AToken _aTokenModify, uint _redeemTokens, uint _borrowAmount) internal view returns (Error, uint, uint) {
        AccountLiquidityLocalVars memory vars;
        uint err;
        MathError mErr;
        AToken[] memory assets = accountAssets[_account];
        for (uint i = 0; i < assets.length; i++) {
            AToken asset = assets[i];
            uint err;
            (err, vars.aTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = asset.getAccountSnapshot(_account);
            if (err != uint(Error.SUCCESS)) {
                return (Error.ERROR, 0, 0);
            }
            vars.collateralFactor = Exp({mantissa: markets[address(asset)].collateralFactorMantissa});
            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(address(asset));
            if (vars.oraclePriceMantissa == 0) {
                return (Error.ERROR, 0, 0);
            }
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});
            (mErr, vars.tokensToDenom) = mulExp3(vars.collateralFactor, vars.exchangeRate, vars.oraclePrice);
            if (mErr != MathError.NO_ERROR) {
                return (Error.ERROR, 0, 0);
            }
            (mErr, vars.sumCollateral) = mulScalarTruncateAddUInt(vars.tokensToDenom, vars.aTokenBalance, vars.sumCollateral);
            if (mErr != MathError.NO_ERROR) {
                return (Error.ERROR, 0, 0);
            }
            (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(vars.oraclePrice, vars.borrowBalance, vars.sumBorrowPlusEffects);
            if (mErr != MathError.NO_ERROR) {
                return (Error.ERROR, 0, 0);
            }
            if (asset == _aTokenModify) {
                if(_borrowAmount == 0){
                    (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(vars.tokensToDenom, _redeemTokens, vars.sumBorrowPlusEffects);
                    if (mErr != MathError.NO_ERROR) {
                        return (Error.ERROR, 0, 0);
                    }
                }
                if(_redeemTokens == 0){
                    (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(vars.oraclePrice, _borrowAmount, vars.sumBorrowPlusEffects);
                    if (mErr != MathError.NO_ERROR) {
                        return (Error.ERROR, 0, 0);
                    }
                }
            }
        }
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (Error.SUCCESS, vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            return (Error.SUCCESS, 0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }

    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
     * @dev seizeTokens = seizeAmount / exchangeRate = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
     * @param _aTokenBorrowed address borrow
     * @param _aTokenCollateral address collateral
     * @param _actualRepayAmount amount
     * @return SUCCESS, number
     */
    function liquidateCalculateSeizeTokens(address _aTokenBorrowed, address _aTokenCollateral, uint _actualRepayAmount) external view returns (uint, uint) {
        uint priceBorrowedMantissa = oracle.getUnderlyingPrice(_aTokenBorrowed);
        uint priceCollateralMantissa = oracle.getUnderlyingPrice(_aTokenCollateral);
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
            return (uint(Error.ERROR), 0);
        }
        uint exchangeRateMantissa = AToken(_aTokenCollateral).exchangeRateStored();
        uint seizeTokens;
        Exp memory numerator;
        Exp memory denominator;
        Exp memory ratio;
        MathError mathErr;

        (mathErr, numerator) = mulExp(liquidationIncentiveMantissa, priceBorrowedMantissa);
        if (mathErr != MathError.NO_ERROR) {
            return (uint(Error.ERROR), 0);
        }
        (mathErr, denominator) = mulExp(priceCollateralMantissa, exchangeRateMantissa);
        if (mathErr != MathError.NO_ERROR) {
            return (uint(Error.ERROR), 0);
        }
        (mathErr, ratio) = divExp(numerator, denominator);
        if (mathErr != MathError.NO_ERROR) {
            return (uint(Error.ERROR), 0);
        }
        (mathErr, seizeTokens) = mulScalarTruncate(ratio, _actualRepayAmount);
        if (mathErr != MathError.NO_ERROR) {
            return (uint(Error.ERROR), 0);
        }
        return (uint(Error.SUCCESS), seizeTokens);
    }


    /**
      * @notice Sets a new price oracle
      * @param _newOracle address PriceOracle
      * @return SUCCESS
      */
    function _setPriceOracle(PriceOracle _newOracle) public returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_PRICE_ORACLE_OWNER_CHECK, uint(Error.ERROR));
        }
        PriceOracle oldOracle = oracle;
        oracle = _newOracle;
        emit NewPriceOracle(oldOracle, _newOracle);
        return uint(Error.SUCCESS);
    }

    /**
     * @notice Sets the closeFactor used when liquidating borrows
     * @param _newCloseFactorMantissa number
     * @return SUCCESS
     */
    function _setCloseFactor(uint _newCloseFactorMantissa) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_CLOSE_FACTOR_OWNER_CHECK, uint(Error.ERROR));
        }
        Exp memory newCloseFactorExp = Exp({mantissa: _newCloseFactorMantissa});
        Exp memory lowLimit = Exp({mantissa: closeFactorMinMantissa});
        if (lessThanOrEqualExp(newCloseFactorExp, lowLimit)) {
            return fail(Error.ERROR, ErrorRemarks.SET_CLOSE_FACTOR_VALIDATION, uint(Error.ERROR));
        }

        Exp memory highLimit = Exp({mantissa: closeFactorMaxMantissa});
        if (lessThanExp(highLimit, newCloseFactorExp)) {
            return fail(Error.ERROR, ErrorRemarks.SET_CLOSE_FACTOR_VALIDATION, uint(Error.ERROR));
        }
        uint oldCloseFactorMantissa = closeFactorMantissa;
        closeFactorMantissa = _newCloseFactorMantissa;

        emit NewCloseFactor(oldCloseFactorMantissa, closeFactorMantissa);
        return uint(Error.SUCCESS);
    }

    /**
     * @notice Sets the collateralFactor for a market
     * @param _aToken address AToken
     * @param _newCollateralFactorMantissa uint
     * @return SUCCESS
     */
    function _setCollateralFactor(AToken _aToken, uint _newCollateralFactorMantissa) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_COLLATERAL_FACTOR_OWNER_CHECK, uint(Error.ERROR));
        }
        Market storage market = markets[address(_aToken)];
        if (!market.isListed) {
            return fail(Error.ERROR, ErrorRemarks.SET_COLLATERAL_FACTOR_NO_EXISTS, uint(Error.ERROR));
        }
        Exp memory newCollateralFactorExp = Exp({mantissa: _newCollateralFactorMantissa});
        Exp memory highLimit = Exp({mantissa: collateralFactorMaxMantissa});
        if (lessThanExp(highLimit, newCollateralFactorExp)) {
            return fail(Error.ERROR, ErrorRemarks.SET_COLLATERAL_FACTOR_VALIDATION, uint(Error.ERROR));
        }
        if (_newCollateralFactorMantissa != 0 && oracle.getUnderlyingPrice(address(_aToken)) == 0) {
            return fail(Error.ERROR, ErrorRemarks.SET_COLLATERAL_FACTOR_WITHOUT_PRICE, uint(Error.ERROR));
        }
        uint oldCollateralFactorMantissa = market.collateralFactorMantissa;
        market.collateralFactorMantissa = _newCollateralFactorMantissa;

        emit NewCollateralFactor(_aToken, oldCollateralFactorMantissa, _newCollateralFactorMantissa);
        return uint(Error.SUCCESS);
    }

    /**
      * @notice Sets maxAssets which controls how many markets can be entered
      * @param _newMaxAssets assets
      * @return SUCCESS
      */
    function _setMaxAssets(uint _newMaxAssets) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_MAX_ASSETS_OWNER_CHECK, uint(Error.ERROR));
        }
        uint oldMaxAssets = maxAssets;
        maxAssets = _newMaxAssets; // push storage

        emit NewMaxAssets(oldMaxAssets, _newMaxAssets);
        return uint(Error.SUCCESS);
    }

    /**
      * @notice Sets liquidationIncentive
      * @param _newLiquidationIncentiveMantissa uint _newLiquidationIncentiveMantissa
      * @return SUCCESS
      */
    function _setLiquidationIncentive(uint _newLiquidationIncentiveMantissa) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_LIQUIDATION_INCENTIVE_OWNER_CHECK, uint(Error.ERROR));
        }
        Exp memory newLiquidationIncentive = Exp({mantissa: _newLiquidationIncentiveMantissa});
        Exp memory minLiquidationIncentive = Exp({mantissa: liquidationIncentiveMinMantissa});
        if (lessThanExp(newLiquidationIncentive, minLiquidationIncentive)) {
            return fail(Error.ERROR, ErrorRemarks.SET_LIQUIDATION_INCENTIVE_VALIDATION, uint(Error.ERROR));
        }

        Exp memory maxLiquidationIncentive = Exp({mantissa: liquidationIncentiveMaxMantissa});
        if (lessThanExp(maxLiquidationIncentive, newLiquidationIncentive)) {
            return fail(Error.ERROR, ErrorRemarks.SET_LIQUIDATION_INCENTIVE_VALIDATION, uint(Error.ERROR));
        }
        uint oldLiquidationIncentiveMantissa = liquidationIncentiveMantissa;
        liquidationIncentiveMantissa = _newLiquidationIncentiveMantissa; // push storage

        emit NewLiquidationIncentive(oldLiquidationIncentiveMantissa, _newLiquidationIncentiveMantissa);
        return uint(Error.SUCCESS);
    }

    /**
      * @notice Add the market to the markets mapping and set it as listed
      * @param _aToken AToken address
      * @return SUCCESS
      */
    function _supportMarket(AToken _aToken) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SUPPORT_MARKET_OWNER_CHECK, uint(Error.ERROR));
        }

        if (markets[address(_aToken)].isListed) {
            return fail(Error.ERROR, ErrorRemarks.SUPPORT_MARKET_EXISTS, uint(Error.ERROR));
        }

        _aToken.aToken();
        markets[address(_aToken)] = Market({isListed: true, collateralFactorMantissa: 0});
        _addMarketInternal(address(_aToken));
        emit MarketListed(_aToken);
        return uint(Error.SUCCESS);
    }
    function _addMarketInternal(address _aToken) internal {
        for (uint i = 0; i < allMarkets.length; i ++) {
            require(allMarkets[i] != AToken(_aToken), "AegisComptroller::_addMarketInternal fail");
        }
        allMarkets.push(AToken(_aToken));
    }

    /**
     * @notice Admin function to change the Pause Guardian
     * @param _newPauseGuardian uint
     * @return SUCCESS
     */
    function _setPauseGuardian(address _newPauseGuardian) public returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.ERROR, ErrorRemarks.SET_PAUSE_GUARDIAN_OWNER_CHECK, uint(Error.ERROR));
        }
        address oldPauseGuardian = pauseGuardian;
        pauseGuardian = _newPauseGuardian;
        emit NewPauseGuardian(oldPauseGuardian, pauseGuardian);
        return uint(Error.SUCCESS);
    }

    function _setMintPaused(AToken _aToken, bool _state) public returns (bool) {
        require(markets[address(_aToken)].isListed, "cannot pause a market that is not listed");
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || _state == true, "only admin can unpause");

        mintGuardianPaused[address(_aToken)] = _state;
        emit ActionPaused(_aToken, "Mint", _state);
        return _state;
    }

    function _setBorrowPaused(AToken _aToken, bool _state) public returns (bool) {
        require(markets[address(_aToken)].isListed, "cannot pause a market that is not listed");
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || _state == true, "only admin can unpause");

        borrowGuardianPaused[address(_aToken)] = _state;
        emit ActionPaused(_aToken, "Borrow", _state);
        return _state;
    }

    function _setTransferPaused(bool _state) public returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || _state == true, "only admin can unpause");

        transferGuardianPaused = _state;
        emit ActionPaused("Transfer", _state);
        return _state;
    }

    function _setSeizePaused(bool _state) public returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || _state == true, "only admin can unpause");

        seizeGuardianPaused = _state;
        emit ActionPaused("Seize", _state);
        return _state;
    }

    function _become(Unitroller _unitroller) public {
        require(msg.sender == _unitroller.admin(), "only unitroller admin can change brains");
        require(_unitroller._acceptImplementation() == 0, "change not authorized");
    }

    /**
     * @notice Checks caller is admin, or this contract is becoming the new implementation
     * @return bool
     */
    function adminOrInitializing() internal view returns (bool) {
        return msg.sender == admin || msg.sender == comptrollerImplementation;
    }

    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint sumBorrowPlusEffects;
        uint aTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }

    event MarketListed(AToken _aToken);
    event MarketEntered(AToken _aToken, address _account);
    event MarketExited(AToken _aToken, address _account);
    event NewCloseFactor(uint _oldCloseFactorMantissa, uint _newCloseFactorMantissa);
    event NewCollateralFactor(AToken _aToken, uint _oldCollateralFactorMantissa, uint _newCollateralFactorMantissa);
    event NewLiquidationIncentive(uint _oldLiquidationIncentiveMantissa, uint _newLiquidationIncentiveMantissa);
    event NewMaxAssets(uint _oldMaxAssets, uint _newMaxAssets);
    event NewPriceOracle(PriceOracle _oldPriceOracle, PriceOracle _newPriceOracle);
    event NewPauseGuardian(address _oldPauseGuardian, address _newPauseGuardian);
    event ActionPaused(string _action, bool _pauseState);
    event ActionPaused(AToken _aToken, string _action, bool _pauseState);
    event NewCompRate(uint _oldCompRate, uint _newCompRate);
    event CompSpeedUpdated(AToken indexed _aToken, uint _newSpeed);
    event DistributedSupplierComp(AToken indexed _aToken, address indexed _supplier, uint _compDelta, uint _compSupplyIndex);
    event DistributedBorrowerComp(AToken indexed _aToken, address indexed _borrower, uint _compDelta, uint _compBorrowIndex);
}