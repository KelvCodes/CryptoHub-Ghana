

    modifier supplyNotExceeded(uint256 quantity) {
        require(_tokenIds.current() + quantity <= maxSupply, "Exceeds max supply");
        _;
    }

    modifier addressLimitNotExceeded(address to, uint256 quantity) {
        require(addressMintCount[to] + quantity <= maxPerAddress, "Exceeds max per address");
        _;
    }

    // ============================================================
    //  MINTING FUNCTIONS
    // ============================================================
    function awardItem(address player, string memory tokenURI)
        public
        onlyMinter
        whenNotPaused
        supplyNotExceeded(1)
        addressLimitNotExceeded(player, 1)
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);
        _tokenIds.increment();
        addressMintCount[player] += 1;

        emit ItemMinted(player, newItemId, tokenURI);
        return newItemId;
    }

    function batchMint(address to, string[] memory uris)
        public
        onlyMinter
        whenNotPaused
        supplyNotExceeded(uris.length)
        addressLimitNotExceeded(to, uris.length)
    {
        for (uint256 i = 0; i < uris.length; i++) {
            uint256 newItemId = _tokenIds.current();
            _mint(to, newItemId);
            _setTokenURI(newItemId, uris[i]);
            _tokenIds.increment();
            addressMintCount[to] += 1;

            emit ItemMinted(to, newItemId, uris[i]);
        }
        emit BatchMinted(to, uris.length);
    }

    // ============================================================
    //  BURN FUNCTIONALITY
    // ============================================================
    function burn(uint256 tokenId) public whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized to burn");
        _burn(tokenId);
    }

    // ============================================================
    //  ADMIN FUNCTIONS
    // ============================================================
    function pause() public onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() public onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setUnrevealedURI(string memory newURI) public onlyOwner {
        _unrevealedURI = newURI;
        emit UnrevealedURIUpdated(newURI);
    }

    function reveal() public onlyOwner {
        revealed = true;
        emit TokenRevealed();
    }

    function addMinter(address minter) public onlyOwner {
        approvedMinters[minter] = true;
        emit MinterUpdated(minter, true);
    }

    function removeMinter(address minter) public onlyOwner {
        approvedMinters[minter] = false;
        emit MinterUpdated(minter, false);
    }

    function setMaxPerAddress(uint256 newLimit) public onlyOwner {
        maxPerAddress = newLimit;
    }

    function setMaxSupply(uint256 newMax) public onlyOwner {
        maxSupply = newMax;
    }

    // ============================================================
    //  READ FUNCTIONS
    // ============================================================
    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokens = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokens;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        if (!revealed) return _unrevealedURI;
        return super.tokenURI(tokenId);
    }

    // ============================================================
    //  OVERRIDES
    // ============================================================
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // ============================================================
    //  FUND WITHDRAWAL
    // ============================================================
    function withdrawFunds(address payable recipient) public onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        (bool success, ) = recipient.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
}


