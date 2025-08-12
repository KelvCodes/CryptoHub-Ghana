ting) public returns (bool, string memory) {
		emit GREETING_CHANGING(greeting, _greeting);
		greeting = _gre(greeting);
		return (true, greeting);
	}
