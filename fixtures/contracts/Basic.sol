
require(false, 'REVERTED WITH REQUIRE');
	}ert('REVERTED WITH REVERT');
	}

	function firesMultiValueEvent(
		string memory str,
		uint256 val,
		bool flag
	) public {
		emit MultiValueEvent(str, val, flag);
	}

	function firesMultiValueIndexedEvent(
		string memory str,
		uint256 val,
		bool flag
	) public {
		emit MultiValueIndexedEvent(str, val, flag);
	}

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
