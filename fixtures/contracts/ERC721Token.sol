, newItemId);
		_setTokenURI(newItemId, tokenURI);

		_tokenIds.increment();
		return newItemId;
	}
}
