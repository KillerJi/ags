pragma solidity ^0.5.16;

/**
 * @title Aegis Comptroller Interface
 * @author Aegis
 */
contract AegisComptrollerInterface {
    bool public constant aegisComptroller = true;

    function enterMarkets(address[] calldata _aTokens) external returns (uint[] memory);
    
    function exitMarket(address _aToken) external returns (uint);

    function mintAllowed(address _aToken, address _minter, uint _mintAmount) external returns (uint);
    
    function mintVerify(address _aToken, address _minter, uint _mintAmount, uint _mintTokens) external;

    function redeemAllowed(address _aToken, address _redeemer, uint _redeemTokens) external returns (uint);
    
    function redeemVerify(address _aToken, address _redeemer, uint _redeemAmount, uint _redeemTokens) external;

    function borrowAllowed(address _aToken, address _borrower, uint _borrowAmount) external returns (uint);
    
    function borrowVerify(address _aToken, address _borrower, uint _borrowAmount) external;

    function repayBorrowAllowed(address _aToken, address _payer, address _borrower, uint _repayAmount) external returns (uint);
    
    function repayBorrowVerify(address _aToken, address _payer, address _borrower, uint _repayAmount, uint _borrowerIndex) external;

    function liquidateBorrowAllowed(address _aTokenBorrowed, address _aTokenCollateral, address _liquidator, address _borrower, uint _repayAmount) external returns (uint);
    
    function liquidateBorrowVerify(address _aTokenBorrowed, address _aTokenCollateral, address _liquidator, address _borrower, uint _repayAmount, uint _seizeTokens) external;

    function seizeAllowed(address _aTokenCollateral, address _aTokenBorrowed, address _liquidator, address _borrower, uint _seizeTokens) external returns (uint);
    
    function seizeVerify(address _aTokenCollateral, address _aTokenBorrowed, address _liquidator, address _borrower, uint _seizeTokens) external;

    function transferAllowed(address _aToken, address _src, address _dst, uint _transferTokens) external returns (uint);
    
    function transferVerify(address _aToken, address _src, address _dst, uint _transferTokens) external;

    /**
     * @notice liquidation
     */
    function liquidateCalculateSeizeTokens(address _aTokenBorrowed, address _aTokenCollateral, uint _repayAmount) external view returns (uint, uint);
}