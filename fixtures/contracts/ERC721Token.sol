ddress player, string memory tokenURI) public returns (uint256) {
        // Get the current token ID from the counter
        uint256 newItemId = _tokenIds.current();

        // Mint a new token with ID `newItemId` to the player's address
        _mint(player, newItemId);

        // Assign the provided metadata URI to the minted token
        _setTokenURI(newItemId, tokenURI);

        // Increment the token ID counter for the next mint
        _tokenIds.increment();

        // Return the ID of the newly minted token
        return newItemId;
    }
}

