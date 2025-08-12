ing greeting);

	constructor(string memory _greeting) {
		greeting = _greeting;
		counter = 0;
	}

	function greet() public view returns (string memory) {
		return greeting;
	}

	function setGreeting(string memory _greeting) public returns (bool, string memory) {
		emit GREETING_CHANGING(greeting, _greeting);
		greeting = _greeting;
		emit GREETING_CHANGED(greeting);
		return (true, greeting);
	}

	function increment() public {
		counter = counter + 1;
	}
}
