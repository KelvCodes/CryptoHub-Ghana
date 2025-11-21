 Indicates whether the contract is paused.
    bool public paused;

    // ------------------------------------------------------------------------
    // =========================== CUSTOM ERRORS ==============================
    // ------------------------------------------------------------------------

    /// @notice Thrown when a non-owner tries to execute a restricted function.
    error Unauthorized(address caller);

    /// @notice Thrown when an invalid address is provided.
    error InvalidAddress(address provided);

    /// @notice Thrown when an invalid value (e.g., zero) is passed.
    error InvalidValue(uint256 value);

    /// @notice Thrown when an action is attempted while the contract is paused.
    error ContractPaused();

    // ------------------------------------------------------------------------
    // ============================== EVENTS =================================
    // ------------------------------------------------------------------------

    event GreetingChanging(string indexed oldGreeting, string indexed newGreeting);
    event GreetingChanged(string indexed newGreeting);
    event CounterIncremented(uint256 newValue);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event ContractPausedState(bool isPaused);

    // ------------------------------------------------------------------------
    // ============================== MODIFIERS ===============================
    // ------------------------------------------------------------------------

    /// @dev Restricts function calls to the contract owner.
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    /// @dev Ensures that contract is not paused.
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ------------------------------------------------------------------------
    // ============================= CONSTRUCTOR ==============================
    // ------------------------------------------------------------------------

    /// @notice Initializes the contract with an initial greeting and sets deployer as the owner.
    /// @param _greeting The initial greeting string.
    constructor(string memory _greeting) {
        owner = msg.sender;
        greeting = _greeting;
        counter = 0;
        paused = false;
    }

    // ------------------------------------------------------------------------
    // ======================== GREETING FUNCTIONS ============================
    // ------------------------------------------------------------------------

    /// @notice Returns the current greeting.
    function greet() external view returns (string memory) {
        return greeting;
    }

    /// @notice Updates the greeting message (default version with events).
    function setGreeting(string memory _newGreeting)
        external
        onlyOwner
        whenNotPaused
        returns (bool success, string memory updatedGreeting)
    {
        emit GreetingChanging(greeting, _newGreeting);
        greeting = _newGreeting;
        emit GreetingChanged(_newGreeting);
        return (true, _newGreeting);
    }

    /// @notice Overloaded version of `setGreeting` allowing event suppression.
    function setGreeting(string memory _newGreeting, bool emitEvents)
        external
        onlyOwner
        whenNotPaused
        returns (bool success, string memory updatedGreeting)
    {
        if (emitEvents) emit GreetingChanging(greeting, _newGreeting);
        greeting = _newGreeting;
        if (emitEvents) emit GreetingChanged(_newGreeting);
        return (true, _newGreeting);
    }

    /// @notice Overloaded version of `setGreeting` with a prefix and suffix concatenation.
    function setGreeting(
        string memory prefix,
        string memory _newGreeting,
        string memory suffix
    )
        external
        onlyOwner
        whenNotPaused
        returns (bool success, string memory updatedGreeting)
    {
        string memory fullGreeting = string(abi.encodePacked(prefix, " ", _newGreeting, " ", suffix));
        emit GreetingChanging(greeting, fullGreeting);
        greeting = fullGreeting;
        emit GreetingChanged(fullGreeting);
        return (true, fullGreeting);
    }

    // ------------------------------------------------------------------------
    // ======================== COUNTER FUNCTIONS =============================
    // ------------------------------------------------------------------------

    /// @notice Increments the counter by 1.
    function increment() external whenNotPaused {
        counter += 1;
        emit CounterIncremented(counter);
    }

    /// @notice Overloaded version: increments counter by a specific value.
    function increment(uint256 _value) external whenNotPaused {
        if (_value == 0) revert InvalidValue(_value);
        counter += _value;
        emit CounterIncremented(counter);
    }

    /// @notice Overloaded version: increments counter multiple times in a loop.
    function increment(uint256 _value, uint256 times) external whenNotPaused {
        if (_value == 0 || times == 0) revert InvalidValue(_value);
        for (uint256 i = 0; i < times; i++) {
            counter += _value;
        }
        emit CounterIncremented(counter);
    }

    /// @notice Returns the current counter value.
    function getCounter() external view returns (uint256) {
        return counter;
    }

    /// @notice Allows the owner to reset the counter to zero.
    function resetCounter() external onlyOwner {
        counter = 0;
        emit CounterIncremented(counter);
    }

    // ------------------------------------------------------------------------
    // ===================== OWNERSHIP & CONTROL ==============================
    // ------------------------------------------------------------------------

    /// @notice Transfers contract ownership to a new address.
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert InvalidAddress(_newOwner);
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    /// @notice Pauses or unpauses the contract (emergency stop).
    function togglePause(bool _paused) external onlyOwner {
        paused = _paused;
        emit ContractPausedState(_paused);
    }

    // ------------------------------------------------------------------------
    // =========================== VIEW HELPERS ===============================
    // ------------------------------------------------------------------------

    /// @notice Returns full contract summary.
    function getDetails()
        external
        view
        returns (
            address currentOwner,
            string memory currentGreeting,
            uint256 currentCounter,
            bool isPaused
        )
    {
        return (owner, greeting, counter, paused);
    }
}

