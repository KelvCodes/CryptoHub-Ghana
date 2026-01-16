
    error Unauthorized(address caller);
    error BlacklistedAddress(address user);
    error InvalidFee(uint256 fee);
    error InvalidMaxTx(uint256 amount);

    // ===========================================
    // EVENTS
    // ===========================================
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event TokenPaused(address indexed by);
    event TokenUnpaused(address indexed by);
    event FeeUpdated(uint256 newFee);
    event MaxTxUpdated(uint256 newLimit);
    event TreasuryUpdated(address indexed newTreasury);
    event AddressBlacklisted(address indexed user);
    event AddressRemovedFromBlacklist(address indexed user);

    // ===========================================
    // CONSTRUCTOR
    // ===========================================
    /**
     * @param name_ Token name (e.g., "Gold")
     * @param symbol_ Token symbol (e.g., "GLD")
     * @param initialSupply Initial token supply (in smallest units)
     * @param treasury Treasury wallet for collecting transaction fees
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address treasury
    ) ERC20(name_, symbol_) {
        if (initialSupply == 0) revert InsufficientAmount();
        if (treasury == address(0)) revert ZeroAddress();

        _mint(msg.sender, initialSupply);
        treasuryWallet = treasury;

        // Assign roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);

        // Set default fee and anti-whale limit
        transactionFee = 100; // 1%
        maxTxAmount = initialSupply / 50; // 2% of total supply

        transferOwnership(msg.sender);
    }

    // ===========================================
    // TOKEN CORE FUNCTIONS
    // ===========================================

    function mint(address to, uint256 amount) external whenNotPaused onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InsufficientAmount();
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(uint256 amount) external whenNotPaused onlyRole(BURNER_ROLE) {
        if (amount == 0) revert InsufficientAmount();
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    // ===========================================
    // TRANSFER HOOK OVERRIDES
    // ===========================================
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (paused()) revert("Token transfers are paused");
        if (blacklisted[from] || blacklisted[to]) revert BlacklistedAddress(from);
        if (amount > maxTxAmount && from != owner() && to != owner()) revert InvalidMaxTx(amount);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 feeAmount = (amount * transactionFee) / 10000; // e.g. 100 = 1%
        uint256 amountAfterFee = amount - feeAmount;

        super._transfer(from, treasuryWallet, feeAmount);
        super._transfer(from, to, amountAfterFee);
    }

    // ===========================================
    // ADMIN / OWNER FUNCTIONS
    // ===========================================
    function setTransactionFee(uint256 newFee) external onlyOwner {
        if (newFee > 500) revert InvalidFee(newFee); // Max 5%
        transactionFee = newFee;
        emit FeeUpdated(newFee);
    }

    function setMaxTransactionLimit(uint256 newLimit) external onlyOwner {
        if (newLimit == 0) revert InvalidMaxTx(newLimit);
        maxTxAmount = newLimit;
        emit MaxTxUpdated(newLimit);
    }

    function setTreasuryWallet(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasuryWallet = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function pause() external onlyOwner {
        _pause();
        emit TokenPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit TokenUnpaused(msg.sender);
    }

    // ===========================================
    // BLACKLIST MANAGEMENT
    // ===========================================
    function blacklistAddress(address user) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        blacklisted[user] = true;
        emit AddressBlacklisted(user);
    }

    function removeFromBlacklist(address user) external onlyOwner {
        blacklisted[user] = false;
        emit AddressRemovedFromBlacklist(user);
    }

    // ===========================================
    // VIEW FUNCTIONS
    // ===========================================
    function getTotalSupply() external view returns (uint256) {
        return totalSupply() / 10 ** decimals();
    }

    function getMyBalance() external view returns (uint256) {
        return balanceOf(msg.sender) / 10 ** decimals();
    }

    function getFeeDetails() external view returns (uint256, address) {
        return (transactionFee, treasuryWallet);
    }
}


