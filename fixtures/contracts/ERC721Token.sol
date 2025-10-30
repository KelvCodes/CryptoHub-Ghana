e token a name and symbol.
     * The deployer becomes the contract owner.
     */
    constructor(string memory baseURI) ERC721("GameItem", "ITM") {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Mint a new token. Only the contract owner can mint.
     * @param player Address receiving the NFT
     * @param tokenURI Metadata URI of the token
     */
    function awardItem(address player, string memory tokenURI)
        public
        onlyOwner
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);
        _tokenIds.increment();

        emit ItemMinted(player, newItemId, tokenURI);
        return newItemId;
    }

    /**
     * @dev Allows a token owner to burn their NFT
     * @param tokenId ID of the token to burn
     */
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not authorized to burn");
        _burn(tokenId);
    }

    /**
     * @dev Returns the total number of tokens minted so far
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @dev Allows the contract owner to update the base metadata URI
     */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /**
     * @dev Override _baseURI() to return the dynamic base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}

