
    // ============================================================
    //  EVENTS
    // ============================================================
    event ItemMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event BatchMinted(address indexed to, uint256 quantity);
    event BaseURIUpdated(string newBaseURI);
    event MinterUpdated(address indexed minter, bool status);
    event ContractPaused(address indexed admin);
    event ContractUnpaused(address indexed admin);

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================
    constructor(string memory baseURI, address royaltyReceiver, uint96 royaltyFeesInBips)
        ERC721("GameItem", "ITM")
    {
        _baseTokenURI = baseURI;

        // Set royalty info (5% = 500 basis points)
        _setDefaultRoyalty(royaltyReceiver, royaltyFeesInBips);
    }

    // ============================================================
    //  MODIFIERS
    // ============================================================
    modifier onlyMinter() {
        require(owner() == _msgSender() || approvedMinters[_msgSender()], "Not authorized to mint");
        _;
    }

    // ============================================================
    //  MINTING FUNCTIONS
    // ============================================================

    /**
     * @dev Mint a single NFT to a player.
     * Only owner or approved minter can call.
     */
    function awardItem(address player, string memory tokenURI)
        public
        onlyMinter
        whenNotPaused
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
     * @dev Batch mint NFTs for efficiency.
     */
    function batchMint(address to, string[] memory uris)
        public
        onlyMinter
        whenNotPaused
    {
        for (uint256 i = 0; i < uris.length; i++) {
            uint256 newItemId = _tokenIds.current();
            _mint(to, newItemId);
            _setTokenURI(newItemId, uris[i]);
            _tokenIds.increment();

            emit ItemMinted(to, newItemId, uris[i]);
        }
        emit BatchMinted(to, uris.length);
    }

    // ============================================================
    //  BURN FUNCTIONALITY
    // ============================================================
    function burn(uint256 tokenId) public whenNotPaused {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not authorized to burn");
        _burn(tokenId);
    }

    // ============================================================
    //  ADMIN CONTROLS
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

    function addMinter(address minter) public onlyOwner {
        approvedMinters[minter] = true;
        emit MinterUpdated(minter, true);
    }

    function removeMinter(address minter) public onlyOwner {
        approvedMinters[minter] = false;
        emit MinterUpdated(minter, false);
    }

    // ============================================================
    //  READ FUNCTIONS
    // ============================================================

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // ============================================================
    //  OVERRIDES (For ERC721 + ERC2981 Compatibility)
    // ============================================================
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ============================================================
    //  WITHDRAWAL FUNCTION
    // ============================================================

    /**
     * @dev Withdraw Ether accidentally sent to contract.
     */
    function withdrawFunds(address payable recipient) public onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        (bool success, ) = recipient.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    // Allow contract to receive Ether
    receive() external payable {}
}

