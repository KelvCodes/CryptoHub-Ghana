=========
    modifier onlyMinter() {
        require(
            owner() == msg.sender || approvedMinters[msg.sender],
            "Not authorized"

        _;
    }

    modifier supplyAvailable(uint256 quantity) {
        require(
            _tokenIds.current() + quantity <= maxSupply,
            "Max supply exceeded"
        );
        _;
    }

    modifier addressLimit(address user, uint256 quantity) {
        require(
            addressMintCount[user] + quantity <= maxPerAddress,
            "Mint limit exceeded"
        );
        _;
    }

    // ============================================================
    //  MINTING LOGIC
    // ============================================================

    /**
     * @notice Public mint
     */
    function mint(uint256 quantity)
        external
        payable
        whenNotPaused
        nonReentrant
        supplyAvailable(quantity)
        addressLimit(msg.sender, quantity)
    {
        require(currentPhase == MintPhase.PUBLIC, "Public mint closed");
        require(msg.value == mintPrice * quantity, "Incorrect ETH");

        _internalMint(msg.sender, quantity);
    }

    /**
     * @notice Whitelist mint using Merkle proof
     */
    function whitelistMint(
        uint256 quantity,
        bytes32[] calldata proof
    )
        external
        payable
        whenNotPaused
        nonReentrant
        supplyAvailable(quantity)
        addressLimit(msg.sender, quantity)
    {
        require(currentPhase == MintPhase.WHITELIST, "Whitelist closed");
        require(_verifyWhitelist(msg.sender, proof), "Invalid proof");
        require(msg.value == mintPrice * quantity, "Incorrect ETH");

        _internalMint(msg.sender, quantity);
    }

    /**
     * @notice Admin mint
     */
    function adminMint(
        address to,
        string memory uri
    )
        external
        onlyMinter
        supplyAvailable(1)
        addressLimit(to, 1)
    {
        _mintSingle(to, uri);
    }

    /**
     * @notice Batch admin mint
     */
    function adminBatchMint(
        address to,
        string[] calldata uris
    )
        external
        onlyMinter
        supplyAvailable(uris.length)
        addressLimit(to, uris.length)
    {
        for (uint256 i = 0; i < uris.length; i++) {
            _mintSingle(to, uris[i]);
        }

        emit BatchMinted(to, uris.length);
    }

    // ============================================================
    //  INTERNAL MINT HELPERS
    // ============================================================

    function _internalMint(address to, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIds.current();
            _mint(to, tokenId);
            _setTokenURI(tokenId, _baseTokenURI);
            _tokenIds.increment();

            addressMintCount[to]++;
            mintTimestamp[tokenId] = block.timestamp;

            emit ItemMinted(to, tokenId);
        }
    }

    function _mintSingle(address to, string memory uri) internal {
        uint256 tokenId = _tokenIds.current();
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _tokenIds.increment();

        addressMintCount[to]++;
        mintTimestamp[tokenId] = block.timestamp;

        emit ItemMinted(to, tokenId);
    }

    // ============================================================
    //  REVEAL & METADATA
    // ============================================================

    function reveal() external onlyOwner {
        revealed = true;
        emit TokenRevealed();
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setUnrevealedURI(string calldata newURI) external onlyOwner {
        _unrevealedURI = newURI;
        emit UnrevealedURIUpdated(newURI);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        if (!revealed) {
            return _unrevealedURI;
        }
        return super.tokenURI(tokenId);
    }

    // ============================================================
    //  ADMIN CONTROLS
    // ============================================================

    function setMintPhase(MintPhase phase) external onlyOwner {
        currentPhase = phase;
        emit MintPhaseUpdated(phase);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function setWhitelistRoot(bytes32 root) external onlyOwner {
        whitelistMerkleRoot = root;
    }

    function setRoyalty(
        address receiver,
        uint96 feeBips
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeBips);
        emit RoyaltyUpdated(receiver, feeBips);
    }

    function addMinter(address minter) external onlyOwner {
        approvedMinters[minter] = true;
        emit MinterUpdated(minter, true);
    }

    function removeMinter(address minter) external onlyOwner {
        approvedMinters[minter] = false;
        emit MinterUpdated(minter, false);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================================
    //  WHITELIST VERIFICATION
    // ============================================================

    function _verifyWhitelist(
        address user,
        bytes32[] calldata proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(proof, whitelistMerkleRoot, leaf);
    }

    // ============================================================
    //  WITHDRAWALS
    // ============================================================

    function withdraw(address payable recipient)
        external
        onlyOwner
        nonReentrant
    {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH");

        (bool success, ) = recipient.call{value: balance}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(recipient, balance);
    }

    // ============================================================
    //  VIEW HELPERS
    // ============================================================

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function tokensOfOwner(address owner_)
        external
        view
        returns (uint256[] memory)
    {
        uint256 balance = balanceOf(owner_);
        uint256[] memory tokens = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner_, i);
        }
        return tokens;
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    receive() external payable {}
}

