ice-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title AdvancedNegativeNumbersV2
 * @author Kelvin
 * @notice Production-grade demonstration of signed integers, ownership,
 * arithmetic safety, indexed events, and emergency controls.
 */
contract AdvancedNegativeNumbersV2 {
    // =============================================================
    // STATE VARIABLES
    // =============================================================

    int256 private _storedNumber;
    address public owner;
    uint256 public updateCount;
    bool public paused;

    // =============================================================
    // ENUMS
    // =============================================================

    enum Operation {
        ADD,
        SUBTRACT,
        MULTIPLY,
        DIVIDE
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
        int256 result
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event Paused(address indexed executor);
    event Unpaused(address indexed executor);

    // =============================================================
    // ERRORS
    // =============================================================

    error Unauthorized();
    error ContractPaused();
    error InvalidValue(string reason);

    // =============================================================
    // MODIFIERS
    // =============================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor(int256 initialValue) {
        owner = msg.sender;
        _storedNumber = initialValue;
    }

    // =============================================================
    // INTERNAL CORE FUNCTIONS
    // =============================================================

    function _updateNumber(int256 newValue) internal {
        int256 oldValue = _storedNumber;
        _storedNumber = newValue;
        updateCount++;

        emit NumberUpdated(msg.sender, oldValue, newValue, updateCount);
    }

    // =============================================================
    // VIEW FUNCTIONS
    // =============================================================

    function getStoredNumber() external view returns (int256) {
        return _storedNumber;
    }

    function getSummary()
        external
        view
        returns (int256 value, uint256 updates, address currentOwner, bool isPaused)
    {
        return (_storedNumber, updateCount, owner, paused);
    }

    // =============================================================
    // ARITHMETIC OPERATIONS
    // =============================================================

    function execute(Operation op, int256 value)
        external
        onlyOwner
        whenNotPaused
    {
        int256 result;

        if (op == Operation.ADD) {
            result = _storedNumber + value;
        } else if (op == Operation.SUBTRACT) {
            result = _storedNumber - value;
        } else if (op == Operation.MULTIPLY) {
            if (value == 0) revert InvalidValue("Multiply by zero");
            result = _storedNumber * value;
        } else if (op == Operation.DIVIDE) {
            if (value == 0) revert InvalidValue("Divide by zero");
            result = _storedNumber / value;
        } else {
            revert InvalidValue("Invalid operation");
        }

        _updateNumber(result);
        emit ArithmeticExecuted(msg.sender, op, value, result);
    }

    // =============================================================
    // BATCH OPERATIONS
    // =============================================================

    function batchExecute(Operation[] calldata ops, int256[] calldata values)
        external
        onlyOwner
        whenNotPaused
    {
        if (ops.length != values.length) {
            revert InvalidValue("Mismatched inputs length");
        }

        if (ops.length == 0) {
            revert InvalidValue("Empty batch");
        }

        for (uint256 i = 0; i < ops.length; i++) {
            execute(ops[i], values[i]);
        }
    }

    // =============================================================
    // PAUSE CONTROL FUNCTIONS
    // =============================================================

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // =============================================================
    // OWNERSHIP FUNCTIONS
    // =============================================================

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidValue("Zero address not allowed");
        }

        if (newOwner == owner) {
            revert InvalidValue("Already the owner");
        }

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // =============================================================
    // EMERGENCY RECOVERY FUNCTION
    // =============================================================

    function forceUpdateNumber(int256 newValue) external onlyOwner whenNotPaused {
        _updateNumber(newValue);
    }
}
