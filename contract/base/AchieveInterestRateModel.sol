pragma solidity ^0.5.16;

import "./InterestRateModel.sol";
import "./AegisMath.sol";

/**
 * @title Achieve InterestRateModel contract
 * @author Aegis
 */
contract AchieveInterestRateModel is InterestRateModel {
    using AegisMath for uint;

    address public owner;
    uint public constant blocksPerYear = 2102400;
    uint public baseRatePerBlock;
    uint public multiplierPerBlock;
    uint public achieveMultiplierPerBlock;
    uint public kink;

    event ChargeInterestRateModel(uint _baseRatePerBlock, uint _multiplierPerBlock, uint _achieveMultiplierPerBlock, uint _kink, address _owner);

    constructor (uint _baseRatePerYear, uint _multiplierPerYear, uint _achieveMultiplierPerYear, uint _kink, address _owner) public {
        owner = _owner;
        _setInterestRateModelInternal(_baseRatePerYear, _multiplierPerYear, _achieveMultiplierPerYear, _kink);
    }

    function updateJumpRateModel(uint _baseRatePerYear, uint _multiplierPerYear, uint _achieveMultiplierPerYear, uint _kink) external {
        require(msg.sender == owner, "AchieveInterestRateModel::updateJumpRateModel owner failer ");
        _setInterestRateModelInternal(_baseRatePerYear, _multiplierPerYear, _achieveMultiplierPerYear, _kink);
    }

    function _setInterestRateModelInternal(uint _baseRatePerYear, uint _multiplierPerYear, uint _achieveMultiplierPerYear, uint _kink) internal {
        kink = _kink;
        baseRatePerBlock = _baseRatePerYear.div(blocksPerYear);
        multiplierPerBlock = _multiplierPerYear.div(blocksPerYear);
        achieveMultiplierPerBlock = _achieveMultiplierPerYear.div(blocksPerYear);
        emit ChargeInterestRateModel(baseRatePerBlock, multiplierPerBlock, achieveMultiplierPerBlock, kink, msg.sender);
    }

    function getBorrowRate(uint _cash, uint _borrows, uint _reserves) public view returns (uint) {
        uint util = utilizationRate(_cash, _borrows, _reserves);
        if (util <= kink) {
            return util.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
        } else {
            uint normalRate = kink.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
            return (util.sub(kink)).mul(achieveMultiplierPerBlock).div(1e18).add(normalRate);
        }
    }

    function getSupplyRate(uint _cash, uint _borrows, uint _reserves, uint _reserveFactorMantissa) public view returns (uint) {
        uint oneMinusReserveFactor = uint(1e18).sub(_reserveFactorMantissa);
        uint borrowRate = getBorrowRate(_cash, _borrows, _reserves);
        uint rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
        return utilizationRate(_cash, _borrows, _reserves).mul(rateToPool).div(1e18);
    }

    function utilizationRate(uint _cash, uint _borrows, uint _reserves) public pure returns (uint) {
        if(0 == _borrows){
            return 0;
        }
        return _borrows.mul(1e18).div(_cash.add(_borrows).sub(_reserves));
    }
}