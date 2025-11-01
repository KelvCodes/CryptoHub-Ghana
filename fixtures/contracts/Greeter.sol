eting history tracking, timestamp logging,
 * and emits events for all state changes.
 */
contract AdvancedGreeter {
    // State variables
    uint256 private counter;
    string private greeting;
    address public owner;
    uint256 public lastUpdated;

    // Store all previous greetings
    string[] public greetingHistory;

    // Events for transparency
    event GreetingChanging(string from, string to);
    event GreetingChanged(string newGreeting, address changedBy, uint256 timestamp);
    event CounterIncremented(uint256 newValue, address incrementedBy);
    event CounterReset(uint256 timestamp);

    // Modifier to restrict access to only the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Access denied: Only owner can perform this action");
        _;
    }

    // Modifier to prevent setting the same greeting
    modifier notSameGreeting(string memory _newGreeting) {
        require(
            keccak256(bytes(_newGreeting)) != keccak256(bytes(greeting)),
            "New greeting must be different from the current one"
        );
        _;
    }

    // Constructor runs only once — sets initial greeting and owner
    constructor(string memory _initialGreeting) {
        greeting = _initialGreeting;
        counter = 0;
        owner = msg.sender;
        lastUpdated = block.timestamp;

        // Record initial greeting in history
        greetingHistory.push(_initialGreeting);
    }

    // --- VIEW FUNCTIONS ---

    /// @notice Returns the current greeting message
    function greet() public view returns (string memory) {
        return greeting;
    }

    /// @notice Returns the current counter value
    function getCounter() public view returns (uint256) {
        return counter;
    }

    /// @notice Returns the number of greetings stored in history
    function getGreetingHistoryCount() public view returns (uint256) {
        return greetingHistory.length;
    }

    /// @notice Returns all past greetings
    function getGreetingHistory() public view returns (string[] memory) {
        return greetingHistory;
    }

    // --- STATE-CHANGING FUNCTIONS ---

    /**
     * @notice Update the greeting message.
     * Emits events before and after changing the greeting.
     * Can only be called by the owner.
     */
    function setGreeting(string memory _newGreeting)
        public
        onlyOwner
        notSameGreeting(_newGreeting)
        returns (bool, string memory)
    {
        emit GreetingChanging(greeting, _newGreeting);

        greeting = _newGreeting;
        lastUpdated = block.timestamp;
        greetingHistory.push(_newGreeting);

        emit GreetingChanged(_newGreeting, msg.sender, block.timestamp);
        return (true, greeting);
    }

    /**
     * @notice Increment the counter by 1.
     * Emits an event after incrementing.
     */
    function increment() public {
        counter += 1;
        emit CounterIncremented(counter, msg.sender);
    }

    /**
     * @notice Reset the counter back to zero.
     * Only the owner can reset the counter.
     */
    function resetCounter() public onlyOwner {
        counter = 0;
        emit CounterReset(block.timestamp);
    }

    /**
     * @notice Transfer contract ownership to a new address.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}

