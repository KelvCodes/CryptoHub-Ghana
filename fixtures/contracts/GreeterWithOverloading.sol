// SPDX-License-Identifier: GNU

pragma solidity ^0.8.13;

/// @title GreeterWithOverloading - A simple smart contract that demonstrates function overloading, 
/// event emissions, and basic state management.
contract GreeterWithOverloading {
    // State variable to track the number of times `increment` is called.
    uint256 counter;

    // Private variable to hold the current greeting message.
    string private greeting;

    // Event emitted before the greeting is updated.
    event GREETING_CHANGING(string from, string to);

    // Event emitted after the greeting has been updated.
    event GREETING_CHANGED(string greeting);

    /// @notice Constructor sets the initial greeting message.
    /// @param _greeting The initial greeting string.
    constructor(string memory _greeting) {
        greeting = _greeting;
        counter = 0;
    }

    /// @notice Returns the current greeting.
    /// @return The current greeting message.
    function greet() public view returns (string memory) {
        return greeting;
    }

    /// @notice Updates the greeting message and emits change events.
    /// @param _greeting The new greeting to be set.
    /// @return success A boolean indicating success.
    /// @return newGreeting The updated greeting string.
    function setGreeting(string memory _greeting) public returns (bool, string memory) {
        emit GREETING_CHANGING(greeting, _greeting); // Emit event before change
        greeting = _greeting;
        emit GREETING_CHANGED(greeting); // Emit event after change
        return (true, greeting);
    }

    /// @notice Overloaded version of setGreeting with event control.
    /// @param _greeting The new greeting to be set.
    /// @param _raiseEvents If true, emits change events; otherwise, skips them.
    /// @return success A boolean indicating success.
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

