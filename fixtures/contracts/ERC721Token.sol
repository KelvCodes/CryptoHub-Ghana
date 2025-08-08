

	function awardItem(address player, string memory tokenURI) public returns (uint256) {
		uint256 newItemId = _tokenIds.current();
		_mint(player, newItemId);
		_setTokenURI(newItemId, tokenURI);

		_tokenIds.increment();
		return newItemId;
	}
}
