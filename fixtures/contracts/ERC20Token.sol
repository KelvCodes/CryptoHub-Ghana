
==== */

    uint256 public totalTransfers;
    uint256 public totalFeesCollected;

    mapping(address => uint256) public userTransferCount;

    /* =============================================================
                            ERRORS
    ============================================================= */

    error ZeroAddress();
    error InsufficientAmount();
    error SupplyCapExceeded();
    error Unauthorized(address caller);
    error Blacklisted(address user);
    error InvalidFee(uint256 fee);
    error InvalidLimit(uint256 value);
    error FeesDisabled();

    /* =============================================================
                            EVENTS
    ============================================================= */

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event FeeUpdated(uint256 newFee);
    event TreasuryUpdated(address indexed treasury);
    event FeeExemptionUpdated(address indexed user, bool status);
    event BlacklistUpdated(address indexed user, bool status);
    event WhitelistUpdated(address indexed user, bool status);
    event FeesToggled(bool enabled);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    event AnalyticsUpdated(address indexed from, address indexed to, uint256 amount);

    /* =============================================================
                            CONSTRUCTOR
    ============================================================= */

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint256 maxSupply_,
        address treasury_
    ) ERC20(name_, symbol_) {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (initialSupply == 0 || maxSupply_ == 0) revert InsufficientAmount();
        if (initialSupply > maxSupply_) revert SupplyCapExceeded();

        MAX_SUPPLY = maxSupply_;
        treasuryWallet = treasury_;

        _mint(msg.sender, initialSupply);

        transactionFee = 100; // 1%
        maxTxAmount = initialSupply / 50;       // 2%
        maxWalletAmount = initialSupply / 25;   // 4%

        /* Roles */
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        feeExempt[msg.sender] = true;
        feeExempt[treasury_] = true;
        whitelisted[msg.sender] = true;

        transferOwnership(msg.sender);
    }

    /* =============================================================
                        CORE TOKEN LOGIC
    ============================================================= */

    function mint(address to, uint256 amount)
        external
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        if (to == address(0)) revert ZeroAddress();
        if (totalSupply() + amount > MAX_SUPPLY) revert SupplyCapExceeded();

        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(uint256 amount)
        external
        whenNotPaused
        onlyRole(BURNER_ROLE)
    {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount)
        external
        whenNotPaused
        onlyRole(BURNER_ROLE)
    {
        uint256 allowed = allowance(from, msg.sender);
        require(allowed >= amount, "Burn exceeds allowance");

        _approve(from, msg.sender, allowed - amount);
        _burn(from, amount);

        emit TokensBurned(from, amount);
    }

    /* =============================================================
                        TRANSFER OVERRIDES
    ============================================================= */

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (paused()) revert("Transfers paused");
        if (blacklisted[from] || blacklisted[to]) revert Blacklisted(from);

        if (!whitelisted[from] && !whitelisted[to]) {
            if (amount > maxTxAmount) revert InvalidLimit(amount);
            if (balanceOf(to) + amount > maxWalletAmount)
                revert InvalidLimit(balanceOf(to) + amount);
        }
    }

    function _transfer(address from, address to, uint256 amount)
        internal
        override
    {
        uint256 feeAmount = 0;

        if (
            feesEnabled &&
            !feeExempt[from] &&
            !feeExempt[to]
        ) {
            feeAmount = (amount * transactionFee) / 10_000;
        }

        uint256 sendAmount = amount - feeAmount;

        if (feeAmount > 0) {
            super._transfer(from, treasuryWallet, feeAmount);
            totalFeesCollected += feeAmount;
        }

        super._transfer(from, to, sendAmount);

        /* analytics */
        totalTransfers++;
        userTransferCount[from]++;
        emit AnalyticsUpdated(from, to, sendAmount);
    }

    /* =============================================================
                        ADMIN CONFIGURATION
    ============================================================= */

    function setTransactionFee(uint256 newFee) external onlyOwner {
        if (newFee > 500) revert InvalidFee(newFee);
        transactionFee = newFee;
        emit FeeUpdated(newFee);
    }

    function toggleFees(bool enabled) external onlyOwner {
        feesEnabled = enabled;
        emit FeesToggled(enabled);
    }

    function setTreasuryWallet(address treasury) external onlyOwner {
        if (treasury == address(0)) revert ZeroAddress();
        treasuryWallet = treasury;
        emit TreasuryUpdated(treasury);
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidLimit(amount);
        maxTxAmount = amount;
    }

    function setMaxWalletAmount(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidLimit(amount);
        maxWalletAmount = amount;
    }

    /* =============================================================
                        BLACKLIST / WHITELIST
    ============================================================= */

    function setBlacklist(address user, bool status) external onlyOwner {
        blacklisted[user] = status;
        emit BlacklistUpdated(user, status);
    }

    function setWhitelist(address user, bool status) external onlyOwner {
        whitelisted[user] = status;
        emit WhitelistUpdated(user, status);
    }

    function setFeeExempt(address user, bool status) external onlyOwner {
        feeExempt[user] = status;
        emit FeeExemptionUpdated(user, status);
    }

    /* =============================================================
                        PAUSE CONTROL
    ============================================================= */

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /* =============================================================
                        EMERGENCY TOOLS
    ============================================================= */

    function rescueERC20(address token, uint256 amount)
        external
        onlyOwner
    {
        IERC20(token).safeTransfer(owner(), amount);
        emit EmergencyWithdraw(token, amount);
    }

    function rescueETH(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    receive() external payable {}

    /* =============================================================
                        VIEW HELPERS
    ============================================================= */

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0));
    }

    function feeInfo() external view returns (uint256 fee, bool enabled) {
        return (transactionFee, feesEnabled);
    }

    function limits() external view returns (uint256 maxTx, uint256 maxWallet) {
        return (maxTxAmount, maxWalletAmount);
    }
}

