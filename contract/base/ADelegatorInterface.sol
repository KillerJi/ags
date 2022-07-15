pragma solidity ^0.5.16;

import "./ADelegactionCommon.sol"

contract ADelegatorInterface is ADelegactionCommon{
    /**
     * @notice Emitted when implementation is changed
     * @param _oldImplementation old
     * @param _newImplementation new
     */
    event NewImplementation(address _oldImplementation, address _newImplementation);

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param _implementation The address of the new implementation for delegation
     * @param _allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param _becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(address _implementation, bool _allowResign, bytes memory _becomeImplementationData) public;
}