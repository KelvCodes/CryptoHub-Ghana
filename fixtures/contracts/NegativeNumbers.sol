// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AdvancedNegativeNumbersV2
 * @author Kelvin
 * @notice Production-grade demonstration of signed integers, ownership,
 * arithmetic safety, indexed events, emergency controls, and enhanced features
 * @dev Implements SafeMath-like behavior through built-in overflow checks (Solidity 0.8+)
 */
contract AdvancedNegativeNumbersV2 {
    // =============================================================
    // STATE VARIABLES
    // =============================================================

    int256 private _storedNumber;
    int256 private _minValue;
    int256 private _maxValue;
    address public owner;
    address public pendingOwner;
    uint256 public updateCount;
    uint256 public operationCount;
    bool public paused;
    bool public initialized;

    // =============================================================
    // ENUMS
    // =============================================================

    enum Operation {
        ADD,
        SUBTRACT,
        MULTIPLY,
        DIVIDE,
        ABS,
        NEGATE,
        POWER,
        MIN,
        MAX
    }

    enum OperationStatus {
        SUCCESS,
        FAILED,
        PENDING
    }

    // =============================================================
    // STRUCTS
    // =============================================================

    struct OperationRecord {
        Operation op;
        int256 input;
        int256 result;
        uint256 timestamp;
        address executor;
        OperationStatus status;
    }

    struct NumberRange {
        int256 min;
        int256 max;
    }

    // =============================================================
    // EVENTS
    // =============================================================

    event NumberUpdated(
        address indexed executor,
        int256 oldValue,
        int256 newValue,
        uint256 updateCount
    );

    event ArithmeticExecuted(
        address indexed executor,
        Operation operation,
        int256 input,
        int256 result,
        uint256 indexed operationId
    );

    event RangeValidationUpdated(
        int256 oldMin,
        int256 oldMax,
        int256 newMin,
        int256 newMax
    );

    event OwnershipTransferRequested(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event Paused(address indexed executor);
    event Unpaused(address indexed executor);
    event ContractInitialized(address indexed initializer, int256 initialValue);
    event EmergencyWithdraw(address indexed executor, uint256 amount);
    event OperationRecorded(uint256 indexed operationId, OperationRecord record);

    // =============================================================
    // ERRORS
    // =============================================================

    error Unauthorized();
    error ContractPaused();
    error InvalidValue(string reason);
    error ValueOutOfRange(int256 value, int256 min, int256 max);
    error InvalidOperation();
    error OverflowDetected();
    error UnderflowDetected();
    error AlreadyInitialized();
    error ZeroAddressNotAllowed();
    error EmptyBatchOperation();
    error ArrayLengthMismatch();
    error OperationFailed(string reason);

    // =============================================================
    // MODIFIERS
    // =============================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyPendingOwner() {
        if (msg.sender != pendingOwner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractPaused();
        _;
    }

    modifier validateValue(int256 value) {
        if (value < _minValue || value > _maxValue) {
            revert ValueOutOfRange(value, _minValue, _maxValue);
        }
        _;
    }

    modifier nonZeroInput(int256 value, string memory errorMessage) {
        if (value == 0) revert InvalidValue(errorMessage);
        _;
    }

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor() {
        owner = msg.sender;
        initialized = false;
    }

    // =============================================================
    // INITIALIZATION FUNCTIONS
    // =============================================================

    function initialize(
        int256 initialValue,
        int256 minRange,
        int256 maxRange
    ) external {
        if (initialized) revert AlreadyInitialized();
        if (msg.sender != owner) revert Unauthorized();
        if (minRange >= maxRange) revert InvalidValue("Invalid range");

        _storedNumber = initialValue;
        _minValue = minRange;
        _maxValue = maxRange;
        initialized = true;
        
        emit ContractInitialized(msg.sender, initialValue);
    }

    // =============================================================
    // INTERNAL CORE FUNCTIONS
    // =============================================================

    function _updateNumber(int256 newValue) internal validateValue(newValue) {
        int256 oldValue = _storedNumber;
        _storedNumber = newValue;
        updateCount++;

        emit NumberUpdated(msg.sender, oldValue, newValue, updateCount);
    }

    function _recordOperation(
        Operation op,
        int256 input,
        int256 result,
        OperationStatus status
    ) internal returns (uint256 operationId) {
        operationId = operationCount++;
        OperationRecord memory record = OperationRecord({
            op: op,
            input: input,
            result: result,
            timestamp: block.timestamp,
            executor: msg.sender,
            status: status
        });
        
        emit OperationRecorded(operationId, record);
        return operationId;
    }

    function _validateOverflow(int256 a, int256 b, Operation op) internal pure {
        if (op == Operation.ADD) {
            if (a > 0 && b > 0 && a > type(int256).max - b) revert OverflowDetected();
            if (a < 0 && b < 0 && a < type(int256).min - b) revert UnderflowDetected();
        } else if (op == Operation.MULTIPLY) {
            if (a != 0 && b != 0) {
                if (a > 0 && b > 0 && a > type(int256).max / b) revert OverflowDetected();
                if (a < 0 && b < 0 && a < type(int256).max / b) revert OverflowDetected();
                if (a > 0 && b < 0 && b < type(int256).min / a) revert UnderflowDetected();
                if (a < 0 && b > 0 && a < type(int256).min / b) revert UnderflowDetected();
            }
        }
    }

    // =============================================================
    // VIEW FUNCTIONS
    // =============================================================

    function getStoredNumber() external view returns (int256) {
        return _storedNumber;
    }

    function getRange() external view returns (NumberRange memory) {
        return NumberRange({min: _minValue, max: _maxValue});
    }

    function getSummary()
        external
        view
        returns (
            int256 value,
            uint256 updates,
            uint256 totalOperations,
            address currentOwner,
            bool isPaused,
            NumberRange memory range
        )
    {
        return (
            _storedNumber,
            updateCount,
            operationCount,
            owner,
            paused,
            NumberRange({min: _minValue, max: _maxValue})
        );
    }

    function isWithinRange(int256 value) external view returns (bool) {
        return value >= _minValue && value <= _maxValue;
    }

    // =============================================================
    // ARITHMETIC OPERATIONS
    // =============================================================

    function execute(Operation op, int256 value)
        external
        onlyOwner
        whenNotPaused
        returns (int256)
    {
        int256 result;
        uint256 operationId;

        if (op == Operation.ADD) {
            _validateOverflow(_storedNumber, value, Operation.ADD);
            result = _storedNumber + value;
        } else if (op == Operation.SUBTRACT) {
            _validateOverflow(_storedNumber, -value, Operation.ADD);
            result = _storedNumber - value;
        } else if (op == Operation.MULTIPLY) {
            if (value == 0) revert InvalidValue("Multiply by zero");
            _validateOverflow(_storedNumber, value, Operation.MULTIPLY);
            result = _storedNumber * value;
        } else if (op == Operation.DIVIDE) {
            if (value == 0) revert InvalidValue("Divide by zero");
            result = _storedNumber / value;
        } else if (op == Operation.ABS) {
            if (_storedNumber < 0) {
                result = -_storedNumber;
            } else {
                result = _storedNumber;
            }
        } else if (op == Operation.NEGATE) {
            result = -_storedNumber;
        } else if (op == Operation.POWER) {
            if (value < 0) revert InvalidValue("Negative exponent not supported");
            if (value == 0) {
                result = 1;
            } else {
                result = _storedNumber ** uint256(value);
            }
        } else if (op == Operation.MIN) {
            result = _storedNumber < value ? _storedNumber : value;
        } else if (op == Operation.MAX) {
            result = _storedNumber > value ? _storedNumber : value;
        } else {
            revert InvalidOperation();
        }

        _updateNumber(result);
        operationId = _recordOperation(op, value, result, OperationStatus.SUCCESS);
        emit ArithmeticExecuted(msg.sender, op, value, result, operationId);
        
        return result;
    }

    // =============================================================
    // BATCH OPERATIONS
    // =============================================================

    function batchExecute(Operation[] calldata ops, int256[] calldata values)
        external
        onlyOwner
        whenNotPaused
        returns (int256[] memory results)
    {
        if (ops.length != values.length) revert ArrayLengthMismatch();
        if (ops.length == 0) revert EmptyBatchOperation();
        if (ops.length > 100) revert InvalidValue("Batch size too large");

        results = new int256[](ops.length);

        for (uint256 i = 0; i < ops.length; i++) {
            results[i] = this.execute(ops[i], values[i]);
        }

        return results;
    }

    // =============================================================
    // RANGE MANAGEMENT FUNCTIONS
    // =============================================================

    function updateRange(int256 newMin, int256 newMax) 
        external 
        onlyOwner 
        whenNotPaused 
    {
        if (newMin >= newMax) revert InvalidValue("Invalid range");
        
        int256 oldMin = _minValue;
        int256 oldMax = _maxValue;
        
        if (_storedNumber < newMin || _storedNumber > newMax) {
            revert ValueOutOfRange(_storedNumber, newMin, newMax);
        }
        
        _minValue = newMin;
        _maxValue = newMax;
        
        emit RangeValidationUpdated(oldMin, oldMax, newMin, newMax);
    }

    // =============================================================
    // PAUSE CONTROL FUNCTIONS
    // =============================================================

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // =============================================================
    // OWNERSHIP FUNCTIONS
    // =============================================================

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddressNotAllowed();
        if (newOwner == owner) revert InvalidValue("Already the owner");

        pendingOwner = newOwner;
        emit OwnershipTransferRequested(owner, newOwner);
    }

    function acceptOwnership() external onlyPendingOwner {
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        
        emit OwnershipTransferred(oldOwner, owner);
    }

    function cancelOwnershipTransfer() external onlyOwner {
        pendingOwner = address(0);
    }

    // =============================================================
    // EMERGENCY FUNCTIONS
    // =============================================================

    function forceUpdateNumber(int256 newValue) 
        external 
        onlyOwner 
        whenNotPaused 
        validateValue(newValue) 
    {
        _updateNumber(newValue);
    }

    function emergencyReset(int256 defaultValue) 
        external 
        onlyOwner 
        whenPaused 
    {
        _updateNumber(defaultValue);
    }

    // =============================================================
    // SAFETY CHECK FUNCTIONS
    // =============================================================

    function safeAdd(int256 a, int256 b) external pure returns (int256) {
        int256 c = a + b;
        if (a > 0 && b > 0 && c < 0) revert OverflowDetected();
        if (a < 0 && b < 0 && c > 0) revert UnderflowDetected();
        return c;
    }

    function safeSubtract(int256 a, int256 b) external pure returns (int256) {
        int256 c = a - b;
        if (b < 0 && a > type(int256).max + b) revert OverflowDetected();
        if (b > 0 && a < type(int256).min + b) revert UnderflowDetected();
        return c;
    }

    function safeMultiply(int256 a, int256 b) external pure returns (int256) {
        if (a == 0 || b == 0) return 0;
        
        int256 c = a * b;
        if (c / a != b) revert OverflowDetected();
        return c;
    }

    // =============================================================
    // VERSION FUNCTION
    // =============================================================

    function getVersion() external pure returns (string memory) {
        return "2.1.0";
    }
}
