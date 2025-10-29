
    // and returns a boolean indicating success and the new string value.
    function setTestString(string memory _testString) public returns (bool, string memory) {
        testString = _testString;
        return (true, testString);
    }
}

