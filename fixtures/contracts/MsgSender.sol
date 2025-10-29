
r runs once when the contract is deployed.
    // It initializes the testString with the value passed as an argument.
    constructor(string memory _testString) {
        testString = _testString;
    }

    // Public view function that returns the address of the message sender.
    // This is the address that called the current function.
    function from() public view returns (address) {
        return msg.sender;
    }

    // Public function to update the testString value.
    // Takes a string input _testString, updates the stored testString,
    // and returns a boolean indicating success and the new string value.
    function setTestString(string memory _testString) public returns (bool, string memory) {
        testString = _testString;
        return (true, testString);
    }
}

