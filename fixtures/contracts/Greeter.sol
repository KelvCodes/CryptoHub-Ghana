

vents before and after changing the greeting.
     * Can only be called by the owner.
     */
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

