 is ERC20 {
	constructor(uint256 initialSupply) ERC20('Gold', 'GLD') {
		_mint(msg.sender, initialSupply);
	}
}
