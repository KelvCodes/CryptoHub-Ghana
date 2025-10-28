
    string private greeting;

    // Event emitted *before* the greeting changes
    // Parameters: the old greeting (`from`) and the new greeting (`to`)
    event GREETING_CHANGING(string from, string to);

    // Event emitted *after* the greeting has been changed
    // Parameter: the new greeting
    event GREETING_CHANGED(string greeting);

    // Constructor function runs once during contract deployment.
    // It sets the initial greeting and initializes the counter to zero.
    constructor(string memory _greeting) {
        greeting = _greeting; // Set initial greeting
        counter = 0;          // Initialize counter
    }

    // Public view function that returns the current greeting.
    // 'view' means it doesn't modify the blockchain state.
    function greet() public view returns (string memory) {
        return greeting;
    }

    // Public function to update the greeting message.
    // Emits two events: one before the change and one after.
    // Returns a boolean `true` for success and the updated greeting.
    function setGreeting(string memory _greeting) public returns (bool, string memory) {
        // Emit event showing the greeting is about to change
        emit GREETING_CHANGING(greeting, _greeting);

        // Update the stored greeting
        greeting = _greeting;

        // Emit event showing the greeting has changed
        emit GREETING_CHANGED(greeting);

        // Indicate success and return the new greeting
        return (true, greeting);
    }

    // Public function to increment the counter by 1.
    // This modifies the blockchain state, so it costs gas.
    function increment() public {
        counter = counter + 1;
    }
}

