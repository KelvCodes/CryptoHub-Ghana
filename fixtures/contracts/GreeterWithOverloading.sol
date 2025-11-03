 like function overloading, modifiers, and events.
contract GreeterWithOverloading {
    // ------------------------------------------------------------------------
    // State Variables
    // ------------------------------------------------------------------------

    /// @notice Tracks how many times `increment()` has been called.
    uint256 private counter;

    /// @notice Holds the current greeting message.
    string private greeting;

    /// @notice The address of the contract owner.
    address public owner;

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    /// @notice Emitted before the greeting is changed.
    event GREETING_CHANGING(string indexed from, string indexed to);

    /// @notice Emitted after the greeting has been changed.
    event GREETING_CHANGED(string indexed newGreeting);

    /// @notice Emitted when the counter is incremented.
    event COUNTER_INCREMENTED(uint256 newValue);

    // ------------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------------

    /// @dev Restricts access to only the owner of the contract.
    modifier onlyOwner() {
        require(msg.sender == owner, "Access denied: Only owner can call this function");
        _;
    }

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    /// @notice Initializes the contract with an initial greeting and sets the deployer as the owner.
    /// @param _greeting The initial greeting string.
    constructor(string memory _greeting) {
        greeting = _greeting;
        counter = 0;
        owner = msg.sender;
    }

    // ------------------------------------------------------------------------
    // Greeting Functions
    // ------------------------------------------------------------------------

    /// @notice Returns the current greeting message.
    /// @return The active greeting message.
    function greet() public view returns (string memory) {
        return greeting;
    }

    /// @notice Updates the greeting and emits change events.
    /// @param _greeting The new greeting string to set.
    /// @return success Indicates whether the operation succeeded.
    /// @return newGreeting The newly updated greeting string.
    function setGreeting(string memory _greeting)
        public
        onlyOwner
        returns (bool success, string memory newGreeting)
    {
        emit GREETING_CHANGING(greeting, _greeting);
        greeting = _greeting;
        emit GREETING_CHANGED(greeting);
        return (true, greeting);
    }

    /// @notice Overloaded version of setGreeting that optionally suppresses events.
    /// @param _greeting The new greeting string.
    /// @param _raiseEvents If true, emits events before and after updating.
    /// @return success Indicates whether the operation succeeded.
    /// @return newGreeting The newly updated greeting string.
    function setGreeting(string memory _greeting, bool _raiseEvents)
        public
        onlyOwner
        returns (bool success, string memory newGreeting)
    {
        if (_raiseEvents) emit GREETING_CHANGING(greeting, _greeting);
        greeting = _greeting;
        if (_raiseEvents) emit GREETING_CHANGED(greeting);
        return (true, greeting);
    }

    // ------------------------------------------------------------------------
    // Counter Functions
    // ------------------------------------------------------------------------

    /// @notice Increments the counter by 1.
    function increment() public {
        counter += 1;
        emit COUNTER_INCREMENTED(counter);
    }

    /// @notice Overloaded version of increment that increases the counter by a specific value.
    /// @param _value The value to increase the counter by.
    function increment(uint256 _value) public {
        require(_value > 0, "Value must be greater than zero");
        counter += _value;
        emit COUNTER_INCREMENTED(counter);
    }

    /// @notice Returns the current counter value.
    /// @return The total count value.
    function getCounter() public view returns (uint256) {
        return counter;
    }

    // ------------------------------------------------------------------------
    // Ownership Management
    // ------------------------------------------------------------------------

    /// @notice Transfers contract ownership to a new address.
    /// @param _newOwner The address of the new owner.
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid address: zero address not allowed");
        owner = _newOwner;
    }
}

