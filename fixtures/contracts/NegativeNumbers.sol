// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @title NegativeNumbers
/// @notice Demonstrates using signed integers (int256) and emitting events that include negative numbers
contract NegativeNumbers {
    /// @notice Stores a signed integer which can be negative
    int256 public storedNegativeNumber;

    /// @notice Event with a single negative number (not indexed)
    event OneNegativeNumber(int256 one);

    /// @notice Event with a single negative number (indexed, allowing filtering)
    event OneNegativeNumberIndexed(int256 indexed one);

    /// @notice Event with two negative numbers (not indexed)
    event TwoNegativeNumbers(int256 one, int256 two);

    /// @notice Event with two negative numbers, both indexed for easier search/filtering
    event TwoNegativeNumbersIndexed(int256 indexed one, int256 indexed two);

    /// @notice Event that mixes a positive unsigned integer, a negative number, and a string
    event OtherNegativeNumbers(uint256 positive, int256 negative, string str);

    /// @notice Same as above but with positive and negative numbers indexed for filtering
    event OtherNegativeNumbersIndexed(
        uint256 indexed positive,
        int256 indexed negative,
        string str
    );

    /// @notice Constructor to initialize the contract with a starting negative number
    /// @param number The initial value to store (can be negative)
    constructor(int256 number) {
        storedNegativeNumber = number;
    }

    /// @notice Emits two events with a single negative number, one indexed and one not
    /// @param number The signed integer to emit
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

