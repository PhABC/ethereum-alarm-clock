pragma solidity 0.4.19;

import "contracts/Interface/SchedulerInterface.sol";
import "contracts/Library/RequestScheduleLib.sol";
import "contracts/Library/SchedulerLib.sol";

/**
 * @title BaseScheduler
 * @dev The foundational contract which provides the API for scheduling future transactions on the Alarm Client.
 */
contract BaseScheduler is SchedulerInterface {
    using SchedulerLib for SchedulerLib.FutureTransaction;

    address public feeRecipient;       // Recipient of the fee.
    address public owner;

    /*
     * @dev Fallback function to be able to receive ether. This can occur
     *  legitimately when scheduling fails due to a validation error.
     */
    function() public payable {}

    /// Event that bubbles up the address of new requests made with this scheduler.
    event NewRequest(address request);

    /**
     * @dev Schedules a new TransactionRequest using the 'full' parameters.
     * @param _toAddress The address destination of the transaction.
     * @param _callData The bytecode that will be included with the transaction.
     * @param _uintArgs [0] The callGas of the transaction.
     * @param _uintArgs [1] The value of ether to be sent with the transaction.
     * @param _uintArgs [2] The size of the execution window of the transaction.
     * @param _uintArgs [3] The (block or timestamp) of when the execution window starts.
     * @param _uintArgs [4] The gasPrice which will be used to execute this transaction.
     * @param _uintArgs [5] The fee attached to this transaction.
     * @param _uintArgs [6] The bounty attached to this transaction.
     * @param _uintArgs [7] The deposit required to claim this transaction.
     * @return The address of the new TransactionRequest.   
     */ 
    function schedule (
        address   _toAddress,
        bytes     _callData,
        uint[8]   _uintArgs
    )
        doReset
        whenNotPaused
        public payable returns (address newRequest)
    {
        futureTransaction.toAddress         = _toAddress;
        futureTransaction.callData          = _callData;
        futureTransaction.callGas           = _uintArgs[0];
        futureTransaction.callValue         = _uintArgs[1];
        futureTransaction.windowSize        = _uintArgs[2];
        futureTransaction.windowStart       = _uintArgs[3];
        futureTransaction.gasPrice          = _uintArgs[4];
        futureTransaction.fee               = _uintArgs[5];
        futureTransaction.bounty            = _uintArgs[6];
        futureTransaction.requiredDeposit   = _uintArgs[7];

        futureTransaction.temporalUnit      = temporalUnit;

        newRequest = futureTransaction.schedule(factoryAddress, feeRecipient, owner);
        require( newRequest != 0x0 );

        NewRequest(newRequest);
        return newRequest;
    }

    event Pause();
    event Unpause();

    bool public paused = false;

    /**
    * @dev Modifier to make a function callable only when the contract is not paused.
    */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /**
    * @dev Modifier to make a function callable only when the contract is paused.
    */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
    * @dev called by the owner to pause, triggers stopped state
    */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        Pause();
    }

    /**
    * @dev called by the owner to unpause, returns to normal state
    */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        Unpause();
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}
