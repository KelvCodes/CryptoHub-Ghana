two);
	event OtherNegativeNumbers(uint256 positive, int256 negative, string str);
	event OtherNegativeNumbersIndexed(
		uint256 indexed positive,
		int256 indexed negative,
		string str
	);

	constructor(int256 number) {
		storedNegativeNumber = number;
	}

	function oneNegativeNumber(int256 number) public {
		emit OneNegativeNumber(number);
		emit OneNegativeNumberIndexed(number);
	}

	function twoNegativeNumbers(int256 number, int256 number2) public {
		emit TwoNegativeNumbers(number, number2);
		emit TwoNegativeNumbersIndexed(number, number2);
	}

	function otherNegativeNumbers(
		int256 number,
		int256 number2,
		string calldata str
	) public {
		emit OtherNegativeNumbers(uint256(number), number2, str);
		emit OtherNegativeNumbersIndexed(uint256(number), number2, str);
	}
}
