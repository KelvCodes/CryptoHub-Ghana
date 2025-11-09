nt256)
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

