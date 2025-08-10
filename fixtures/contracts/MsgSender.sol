String) {
		testString = _testString;
	}

	function from() public view returns (address) {
		return msg.sender;
	}

	function setTestString(string memory _testString) public returns (bool, string memory) {
		testString = _testString;
		return (true, testString);
	}
}
