
ra MyContract {
	string private myAttribute;

	function getAttr() public view returns (string memory) {
		return myAttribute;
	}
}
