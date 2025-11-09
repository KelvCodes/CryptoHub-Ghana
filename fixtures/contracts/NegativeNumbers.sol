sIn
integer to emit
    function oneNegativeNumber(int256 number) public {
        emit OneNegativeNumber(number);               // emits without indexing
        emit OneNegativeNumberIndexed(number);        // emits with indexing for easier filtering
    }

    /// @notice Emits two events with two negative numbers, one with indexing and one without
    /// @param number First signed integer
    /// @param number2 Second signed integer
    function twoNegativeNumbers(int256 number, int256 number2) public {
        emit TwoNegativeNumbers(number, number2);                 // emits without indexing
        emit TwoNegativeNumbersIndexed(number, number2);          // emits with both numbers indexed
    }

    /// @notice Emits events mixing positive and negative numbers and a string
    /// @dev Demonstrates casting from int256 to uint256 to show a positive representation
    /// @param number First signed integer (cast to uint256)
    /// @param number2 Second signed integer (stored as negative)
    /// @param str A descriptive string or message
    function otherNegativeNumbers(
        int256 number,
        int256 number2,
        string calldata str
    ) public {
        // Cast first int256 number to uint256 so it becomes a positive value in the event
        emit OtherNegativeNumbers(uint256(number), number2, str);

        // Same as above but with indexed fields for easier filtering on the blockchain
        emit OtherNegativeNumbersIndexed(uint256(number), number2, str);
    }
}

