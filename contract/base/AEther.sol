pragma solidity ^0.5.16;

import "./AToken.sol";

/**
 * @notice AEther contract
 * @author Aegis
 */
contract AEther is AToken {

    /**
     * @notice init AEther contract
     * @param _comptroller comptroller
     * @param _interestRateModel interestRate
     * @param _initialExchangeRateMantissa exchangeRate
     * @param _name name
     * @param _symbol symbol
     * @param _decimals decimals
     * @param _admin owner address
     */
    constructor (AegisComptrollerInterface _comptroller, InterestRateModel _interestRateModel, uint _initialExchangeRateMantissa, string memory _name,
            string memory _symbol, uint8 _decimals, address payable _admin) public {
        admin = msg.sender;
        initialize(_name, _symbol, _decimals, _comptroller, _interestRateModel, _initialExchangeRateMantissa);
        admin = _admin;
    }

    function () external payable {
        (uint err, uint item) = mintInternal(msg.value);
        requireNoError(err, "AEther mint fail");
    }

    function mint() external payable {
        (uint err, uint item) = mintInternal(msg.value);
        require(err == uint(Error.SUCCESS), "AEther::mint fail");
    }
    function redeem(uint _redeemTokens) external returns (uint) {
        return redeemInternal(_redeemTokens);
    }
    function redeemUnderlying(uint _redeemAmount) external returns (uint) {
        return redeemUnderlyingInternal(_redeemAmount);
    }
    function borrow(uint _borrowAmount) external returns (uint) {
        return borrowInternal(_borrowAmount);
    }
    function repayBorrow() external payable {
        (uint err, uint item) = repayBorrowInternal(msg.value);
        require(err == uint(Error.SUCCESS), "AEther::repayBorrow fail");
    }
    function repayBorrowBehalf(address _borrower) external payable {
        (uint err, uint item) = repayBorrowBehalfInternal(_borrower, msg.value);
        require(err == uint(Error.SUCCESS), "AEther::repayBorrowBehalf fail");
    }
    function liquidateBorrow(address _borrower, AToken _collateral) external payable {
        (uint err, uint item) = liquidateBorrowInternal(_borrower, msg.value, _collateral);
        requireNoError(err, "AEther::liquidateBorrow fail");
    }

    function getCashPrior() internal view returns (uint) {
        (MathError err, uint startingBalance) = subUInt(address(this).balance, msg.value);
        require(err == MathError.NO_ERROR);
        return startingBalance;
    }

    function doTransferIn(address _from, uint _amount) internal returns (uint) {
        require(msg.sender == _from, "AEther::doTransferIn sender fail");
        require(msg.value == _amount, "AEther::doTransferIn value fail");
        return _amount;
    }

    function doTransferOut(address payable _to, uint _amount) internal {
        _to.transfer(_amount);
    }

    function requireNoError(uint errCode, string memory message) internal pure {
        if (errCode == uint(Error.SUCCESS)) {
            return;
        }

        bytes memory fullMessage = new bytes(bytes(message).length + 5);
        uint i;

        for (i = 0; i < bytes(message).length; i++) {
            fullMessage[i] = bytes(message)[i];
        }

        fullMessage[i+0] = byte(uint8(32));
        fullMessage[i+1] = byte(uint8(40));
        fullMessage[i+2] = byte(uint8(48 + ( errCode / 10 )));
        fullMessage[i+3] = byte(uint8(48 + ( errCode % 10 )));
        fullMessage[i+4] = byte(uint8(41));

        require(errCode == uint(Error.SUCCESS), string(fullMessage));
    }
}