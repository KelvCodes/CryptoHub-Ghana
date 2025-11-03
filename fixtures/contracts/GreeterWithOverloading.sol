eting that optionally suppresses events.
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

