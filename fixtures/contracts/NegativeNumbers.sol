
	mber2,
		string calldata str
	) public {
		emit OtherNegativeNumbers(uint256(number), number2, str);
		emit OtherNegativeNumbersIndexed(uint256(number), number2, str);
	}
}
