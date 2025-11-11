tAmount();
    error Unauthorized(address caller);

    // ===========================================
    // EVENTS
    // ===========================================
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event TokenPaused(address indexed by);
    event TokenUnpaused(address indexed by);

    // ===========================================
    // CONSTRUCTOR
    // ===========================================
    /**
     * @notice Deploys the token with a name, symbol, and initial supply.
     * @param name_ The token name (e.g., "Gold").
     * @param symbol_ The token symbol (e.g., "GLD").
     * @param initialSupply The initial number of tokens (in wei units, e.g., 1000 * 10**decimals()).
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        if (initialSupply == 0) revert InsufficientAmount();
        _mint(msg.sender, initialSupply);
        transferOwnership(msg.sender);
    }

    // ===========================================
    // TOKEN FUNCTIONS
    // ===========================================

    /// @notice Allows the owner to mint new tokens to a specified address.
    /// @param to The recipient of the minted tokens.
    /// @param amount The number of tokens to mint.
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InsufficientAmount();

        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /// @notice Allows any token holder to burn (destroy) their tokens.
    /// @param amount The number of tokens to burn.
    function burn(uint256 amount) external whenNotPaused {
        if (amount == 0) revert InsufficientAmount();
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    // ===========================================
    // PAUSING FUNCTIONALITY
    // ===========================================

    /// @notice Pauses all token transfers and minting (onlyOwner).
    function pause() external onlyOwner {
        _pause();
        emit TokenPaused(msg.sender);
    }

    /// @notice Unpauses token transfers and minting (onlyOwner).
    function unpause() external onlyOwner {
        _unpause();
        emit TokenUnpaused(msg.sender);
    }

    /// @dev Overrides ERC20 hook to enforce pause logic.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "Token transfers are paused");
    }

    // ===========================================
    // HELPER FUNCTIONS
    // ===========================================

    /// @notice Returns the token's total supply formatted in full units (not wei).
    function getTotalSupply() external view returns (uint256) {
        return totalSupply() / 10 ** decimals();
    }

    /// @notice Returns the caller’s balance in full token units.
    function getMyBalance() external view returns (uint256) {
        return balanceOf(msg.sender) / 10 ** decimals();
    }
}

