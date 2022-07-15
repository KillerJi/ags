pragma solidity ^0.5.16;

contract ADelegateInterface is ADelegactionCommon {
    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @param _data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes memory _data) public;

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() public;
}