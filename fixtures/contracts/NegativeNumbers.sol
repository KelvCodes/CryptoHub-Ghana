 number2);
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
