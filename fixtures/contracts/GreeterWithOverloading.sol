
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
