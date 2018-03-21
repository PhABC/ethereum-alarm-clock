pragma solidity 0.4.19;

import "contracts/Interface/RequestFactoryInterface.sol";
import "contracts/Interface/RequestTrackerInterface.sol";
import "contracts/TransactionRequestCore.sol";
import "contracts/Library/RequestLib.sol";
import "contracts/IterTools.sol";
import "contracts/CloneFactory.sol";

/**
 * @title RequestFactory
 * @dev Contract which will produce new TransactionRequests.
 */
contract RequestFactory is RequestFactoryInterface, CloneFactory {
    using IterTools for bool[6];

    // RequestTracker of this contract.
    RequestTrackerInterface public requestTracker;
    TransactionRequestCore public transactionRequestCore;

    function RequestFactory(
        address _trackerAddress,
        address _transactionRequestCore
    ) public {
        require( _trackerAddress != 0x0 );
        require( _transactionRequestCore != 0x0 );

        requestTracker = RequestTrackerInterface(_trackerAddress);
        transactionRequestCore = TransactionRequestCore(_transactionRequestCore);
    }

    /**
     * @dev The lowest level interface for creating a transaction request.
     *
     * @param _addressArgs [0] -  meta.owner
     * @param _addressArgs [1] -  paymentData.feeRecipient
     * @param _addressArgs [2] -  txnData.toAddress
     * @param _addressArgs [3] -  meta.externalOwner
     * @param _uintArgs [0]    -  paymentData.fee
     * @param _uintArgs [1]    -  paymentData.bounty
     * @param _uintArgs [2]    -  schedule.claimWindowSize
     * @param _uintArgs [3]    -  schedule.freezePeriod
     * @param _uintArgs [4]    -  schedule.reservedWindowSize
     * @param _uintArgs [5]    -  schedule.temporalUnit
     * @param _uintArgs [6]    -  schedule.windowSize
     * @param _uintArgs [7]    -  schedule.windowStart
     * @param _uintArgs [8]    -  txnData.callGas
     * @param _uintArgs [9]    -  txnData.callValue
     * @param _uintArgs [10]   -  txnData.gasPrice
     * @param _uintArgs [11]   -  claimData.requiredDeposit
     * @param _callData        -  The call data
     */
    function createRequest(
        address[4]  _addressArgs,
        uint[12]    _uintArgs,
        bytes       _callData
    )
        public payable returns (address)
    {
        // Create a new transaction request clone from transactionRequestCore.
        address transactionRequest = createClone(transactionRequestCore);

        // Call initialize on the transaction request clone.
        TransactionRequestCore(transactionRequest).initialize.value(msg.value)(
            [
                msg.sender,       // Created by
                _addressArgs[0],  // meta.owner
                _addressArgs[1],  // paymentData.feeRecipient
                _addressArgs[2],  // txnData.toAddress
                _addressArgs[3]   // meta.externalOwner
            ],
            _uintArgs,            //uint[12]
            _callData
        );

        // Track the address locally
        requests[transactionRequest] = true;

        // Log the creation.
        RequestCreated(transactionRequest, _addressArgs[0]);

        // Add the transaction request to the tracker along with the `windowStart`
        requestTracker.addRequest(transactionRequest, _uintArgs[7]);

        return transactionRequest;
    }

    /**
     *  The same as createRequest except that it requires validation prior to
     *  creation.
     *
     *  Parameters are the same as `createRequest`
     */
    function createValidatedRequest(
        address[4]  _addressArgs,
        uint[12]    _uintArgs,
        bytes       _callData
    )
        public payable returns (address)
    {
        bool[6] memory isValid = validateRequestParams(
            _addressArgs,
            _uintArgs,
            _callData,
            msg.value
        );

        if (!isValid.all()) {
            if (!isValid[0]) {
                ValidationError(uint8(Errors.InsufficientEndowment));
            }
            if (!isValid[1]) {
                ValidationError(uint8(Errors.ReservedWindowBiggerThanExecutionWindow));
            }
            if (!isValid[2]) {
                ValidationError(uint8(Errors.InvalidTemporalUnit));
            }
            if (!isValid[3]) {
                ValidationError(uint8(Errors.ExecutionWindowTooSoon));
            }
            if (!isValid[4]) {
                ValidationError(uint8(Errors.CallGasTooHigh));
            }
            if (!isValid[5]) {
                ValidationError(uint8(Errors.EmptyToAddress));
            }

            // Try to return the ether sent with the message.  If this failed
            // then revert() to force it to be returned
            if (!msg.sender.send(msg.value)) {
                revert();
            }
            return 0x0;
        }

        return createRequest(_addressArgs, _uintArgs, _callData);
    }

    /// ----------------------------
    /// Internal
    /// ----------------------------

    /*
     *  @dev The enum for launching `ValidationError` events and mapping them to an error.
     */
    enum Errors {
        InsufficientEndowment,
        ReservedWindowBiggerThanExecutionWindow,
        InvalidTemporalUnit,
        ExecutionWindowTooSoon,
        CallGasTooHigh,
        EmptyToAddress
    }

    event ValidationError(uint8 error);

    /*
     * @dev Validate the constructor arguments for either `createRequest` or `createValidatedRequest`.
     */
    function validateRequestParams(
        address[4]  _addressArgs,
        uint[12]    _uintArgs,
        bytes       _callData,
        uint        _endowment
    )
        public view returns (bool[6])
    {
        return RequestLib.validate(
            [
                msg.sender,      // meta.createdBy
                _addressArgs[0],  // meta.owner
                _addressArgs[1],  // paymentData.feeRecipient
                _addressArgs[2],   // txnData.toAddress
                _addressArgs[3]  // meta.externalOwner
            ],
            _uintArgs,
            _callData,
            _endowment
        );
    }

    /// Mapping to hold known requests.
    mapping (address => bool) requests;

    function isKnownRequest(address _address)
        public view returns (bool isKnown)
    {
        return requests[_address];
    }
}
