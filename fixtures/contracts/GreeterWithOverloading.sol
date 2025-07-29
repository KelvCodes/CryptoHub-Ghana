lic returns (bool, string memory) {
		emit GREETING_CHANGING(greeting, _greeting);
		greeting = _greeting;
		emit GREETING_CHANGED(greeting);
		return (true, greeting);
	}

	// function overlading with additional parameter
	function setGreeting(string memory _greeting, bool _raiseEvents)
		public
		returns (bool, string memory)
	{
		if (_raiseEvents) {
			emit GREETING_CHANGING(greeting, _greeting);
		}
		greeting = _greeting;
		if (_raiseEvents) {
			emit GREETING_CHANGED(greeting);
		}
		return (true, greeting);
	}

	function increment() public {
		counter = counter + 1;
	}
}
