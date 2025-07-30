



orize() public {
		if (msg.sender != owner) revert Unauthorized();

		owner.transfer(address(this).balance);
	}

	function badRequire() public {
		if (1 < 2) revert CustomError('reverted using custom Error');

		owner.transfer(address(this).balance);
	}
}
