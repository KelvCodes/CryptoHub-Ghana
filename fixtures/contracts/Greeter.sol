g(string memory _greeting) public returns (bool, string memory) {
		emit GREETING_CHANGING(greeting, _greeting);
		greeting = _gre(greeting);
		return (true, greeting);
	}

	function increment() public {
		counter = counter + 1;
	}
}
