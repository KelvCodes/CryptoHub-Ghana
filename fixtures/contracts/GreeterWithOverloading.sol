
    /// @return newGreeting The updated greeting string.
    function setGreeting(string memory _greeting, bool _raiseEvents)
        public
        returns (bool, string memory)
    {
        if (_raiseEvents) {
            emit GREETING_CHANGING(greeting, _greeting); // Emit before change
        }
        greeting = _greeting;
        if (_raiseEvents) {
            emit GREETING_CHANGED(greeting); // Emit after change
        }
        return (true, greeting);
    }

    /// @notice Increments the counter by 1.
    function increment() public {
        counter = counter + 1;
    }
}

