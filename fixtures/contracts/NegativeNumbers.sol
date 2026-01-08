

    // ========
    // 🔹 EVENTS
    // =============================================================

    /// @notice Emitted when a new signed number is stored.
    event NumberUpdated(address indexed updater, int256 oldValue, int256 newValue, uint256 updateCount);

    /// @notice Emitted when arithmetic operations occur.
    event ArithmeticOperation(
        address indexed executor,
        string operation,
        int256 inputValue,
        int256 result
    );

    /// @notice Demonstrates single and double negative number emissions.
    event OneNegativeNumber(int256 one);
    event OneNegativeNumberIndexed(int256 indexed one);
    event TwoNegativeNumbers(int256 one, int256 two);
    event TwoNegativeNumbersIndexed(int256 indexed one, int256 indexed two);

    /// @notice Mixed event with unsigned (positive), signed (negative), and string data.
    event OtherNegativeNumbers(uint256 positive, int256 negative, string str);
    event OtherNegativeNumbersIndexed(uint256 indexed positive, int256 indexed negative, string str);

    /// @notice Ownership change event.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // =============================================================
    // 🔹 CUSTOM ERRORS
    // =============================================================

    error Unauthorized();
    error InvalidOperation(string message);

    // =============================================================
    // 🔹 MODIFIERS
    // =============================================================

    /// @dev Restricts function access to the contract owner only.
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // =============================================================
    // 🔹 CONSTRUCTOR
    // =============================================================

    /**
     * @notice Initializes the contract with an initial signed integer.
     * @param number The initial number (can be negative or positive).
     */
    constructor(int256 number) {
        storedNumber = number;
        owner = msg.sender;
        updateCount = 0;
    }

    // =============================================================
    // 🔹 CORE NUMBER FUNCTIONS
    // =============================================================

    /**
     * @notice Returns the current stored number.
     * @return The currently stored signed integer.
     */
    function getStoredNumber() public view returns (int256) {
        return storedNumber;
    }

    /**
     * @notice Sets a new signed integer value.
     * @param newNumber The new signed integer to store.
     */
    function setStoredNumber(int256 newNumber) public onlyOwner {
        int256 oldValue = storedNumber;
        storedNumber = newNumber;
        updateCount++;
        emit NumberUpdated(msg.sender, oldValue, newNumber, updateCount);
    }

    /**
     * @notice Resets the stored number back to zero.
     */
    function resetNumber() public onlyOwner {
        int256 oldValue = storedNumber;
        storedNumber = 0;
        updateCount++;
        emit NumberUpdated(msg.sender, oldValue, storedNumber, updateCount);
    }

    // =============================================================
    // 🔹 ARITHMETIC OPERATIONS
    // =============================================================

    /**
     * @notice Adds a signed number to the stored number.
     * @param value The value to add (can be negative or positive).
     */
    function addNumber(int256 value) public onlyOwner {
        int256 result = storedNumber + value;
        storedNumber = result;
        updateCount++;
        emit ArithmeticOperation(msg.sender, "Addition", value, result);
    }

    /**
     * @notice Subtracts a signed number from the stored number.
     * @param value The value to subtract.
     */
    function subtractNumber(int256 value) public onlyOwner {
        int256 result = storedNumber - value;
        storedNumber = result;
        updateCount++;
        emit ArithmeticOperation(msg.sender, "Subtraction", value, result);
    }

    /**
     * @notice Multiplies the stored number by a signed integer.
     * @param value The multiplier (can be negative or positive).
     */
    function multiplyNumber(int256 value) public onlyOwner {
        if (value == 0) revert InvalidOperation("Cannot multiply by zero");
        int256 result = storedNumber * value;
        storedNumber = result;
        updateCount++;
        emit ArithmeticOperation(msg.sender, "Multiplication", value, result);
    }

    /**
     * @notice Divides the stored number by a signed integer.
     * @param value The divisor (must not be zero).
     */
    function divideNumber(int256 value) public onlyOwner {
        if (value == 0) revert InvalidOperation("Cannot divide by zero");
        int256 result = storedNumber / value;
        storedNumber = result;
        updateCount++;
        emit ArithmeticOperation(msg.sender, "Division", value, result);
    }

    // =============================================================
    // 🔹 DEMO EVENT FUNCTIONS (FROM ORIGINAL CONTRACT)
    // =============================================================

    function oneNegativeNumber(int256 number) public {
        emit OneNegativeNumber(number);
        emit OneNegativeNumberIndexed(number);
    }

    function twoNegativeNumbers(int256 number, int256 number2) public {
        emit TwoNegativeNumbers(number, number2);
        emit TwoNegativeNumbersIndexed(number, number2);
    }

    function otherNegativeNumbers(int256 number, int256 number2, string calldata str) public {
        emit OtherNegativeNumbers(uint256(number), number2, str);
        emit OtherNegativeNumbersIndexed(uint256(number), number2, str);
    }

    // =============================================================
    // 🔹 OWNERSHIP MANAGEMENT
    // =============================================================

    /**
     * @notice Transfers ownership of the contract to another address.
     * @param newOwner The new owner's address.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert InvalidOperation("Invalid address: zero address not allowed");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // =============================================================
    // 🔹 SUMMARY HELPER
    // =============================================================

    /**
     * @notice Returns a summary of the contract's state.
     * @return currentValue The stored signed number.
     * @return totalUpdates How many times the number was changed.
     * @return currentOwner The address of the owner.
     */
    function getSummary()
        public
        view
        returns (int256 currentValue, uint256 totalUpdates, address currentOwner)
    {
        return (storedNumber, updateCount, owner);
    }
}

