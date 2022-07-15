pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./AToken.sol";
import "./AErc20.sol";
import "./PriceOracle.sol";
import "./EIP20Interface.sol";

/**
 * @title Aegis God contract
 * @author Aegis
 */
 interface AegisGodInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (AToken[] memory);
}
contract AegisGod is AegisGodInterface {
    function aTokenMetadata(AToken _aToken) public returns (ATokenMetadata memory) {
        uint exchangeRateCurrent = _aToken.exchangeRateCurrent();
        AegisGodInterface comptroller = AegisGodInterface(address(_aToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(_aToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;
        if (keccak256(abi.encodePacked((_aToken.symbol()))) == keccak256(abi.encodePacked(('ETH-AEGIS')))) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            AErc20 aErc20 = AErc20(address(_aToken));
            underlyingAssetAddress = aErc20.underlying();
            underlyingDecimals = EIP20Interface(aErc20.underlying()).decimals();
        }
        return ATokenMetadata({
            aToken: address(_aToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: _aToken.supplyRatePerBlock(),
            borrowRatePerBlock: _aToken.borrowRatePerBlock(),
            reserveFactorMantissa: _aToken.reserveFactorMantissa(),
            totalBorrows: _aToken.totalBorrows(),
            totalReserves: _aToken.totalReserves(),
            totalSupply: _aToken.totalSupply(),
            totalCash: _aToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            aTokenDecimals: _aToken.decimals(),
            underlyingDecimals: underlyingDecimals
        });
    }
    function aTokenMetadataAll(AToken[] calldata _aTokens) external returns (ATokenMetadata[] memory) {
        uint aTokenCount = _aTokens.length;
        ATokenMetadata[] memory res = new ATokenMetadata[](aTokenCount);
        for (uint i = 0; i < aTokenCount; i++) {
            res[i] = aTokenMetadata(_aTokens[i]);
        }
        return res;
    }

    function cTokenBalances(AToken _aToken, address payable _account) public returns (ATokenBalances memory) {
        uint balanceOf = _aToken.balanceOf(_account);
        uint borrowBalanceCurrent = _aToken.borrowBalanceCurrent(_account);
        uint balanceOfUnderlying = _aToken.balanceOfUnderlying(_account);
        uint tokenBalance;
        uint tokenAllowance;
        if (keccak256(abi.encodePacked((_aToken.symbol()))) == keccak256(abi.encodePacked(('ETH-AEGIS')))) {
            tokenBalance = _account.balance;
            tokenAllowance = _account.balance;
        } else {
            AErc20 aErc20 = AErc20(address(_aToken));
            EIP20Interface underlying = EIP20Interface(aErc20.underlying());
            tokenBalance = underlying.balanceOf(_account);
            tokenAllowance = underlying.allowance(_account, address(_aToken));
        }
        return ATokenBalances({
            aToken: address(_aToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }
    function aTokenBalancesAll(AToken[] calldata _aTokens, address payable _account) external returns (ATokenBalances[] memory) {
        uint aTokenCount = _aTokens.length;
        ATokenBalances[] memory res = new ATokenBalances[](aTokenCount);
        for (uint i = 0; i < aTokenCount; i++) {
            res[i] = cTokenBalances(_aTokens[i], _account);
        }
        return res;
    }

    function aTokenUnderlyingPrice(AToken _aToken) public returns (ATokenUnderlyingPrice memory) {
        AegisGodInterface comptroller = AegisGodInterface(address(_aToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();
        return ATokenUnderlyingPrice({
            aToken: address(_aToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(address(_aToken))
        });
    }
    function aTokenUnderlyingPriceAll(AToken[] calldata _aTokens) external returns (ATokenUnderlyingPrice[] memory) {
        uint aTokenCount = _aTokens.length;
        ATokenUnderlyingPrice[] memory res = new ATokenUnderlyingPrice[](aTokenCount);
        for (uint i = 0; i < aTokenCount; i++) {
            res[i] = aTokenUnderlyingPrice(_aTokens[i]);
        }
        return res;
    }

    function getAccountLimits(AegisGodInterface _comptroller, address _account) public returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = _comptroller.getAccountLiquidity(_account);
        require(errorCode == 0);
        return AccountLimits({
            markets: _comptroller.getAssetsIn(_account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    struct ATokenMetadata {
        address aToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint aTokenDecimals;
        uint underlyingDecimals;
    }
    struct ATokenBalances {
        address aToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }
    struct ATokenUnderlyingPrice {
        address aToken;
        uint underlyingPrice;
    }
    struct AccountLimits {
        AToken[] markets;
        uint liquidity;
        uint shortfall;
    }
}