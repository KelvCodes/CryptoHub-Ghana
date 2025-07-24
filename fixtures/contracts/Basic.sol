on firesMultiValueIndexedEvent(
	

	function firesStringEvent(string memory _str) public {
		emit StringEvent(_str);
	}

	function firesMultiValueIndexedEventWithStringIndexed(
		string calldata str,
		uint256 val,
		bool flag
	) public {
		emit MultiValueIndexedEventWithStringIndexed(str, val, flag);
	}
}
