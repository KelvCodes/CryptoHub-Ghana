
e Returns the current counter value
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

