tString(string memory _testString) public returns (bool, string memory) {
		testString = _testString;
		return (true, testString);
	}
}
